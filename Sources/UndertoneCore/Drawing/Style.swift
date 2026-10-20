import Foundation
import simd

/// What a picture is made of. Each style is a port of the function of the same name in `prototype/gen.py`.
public enum Style: String, CaseIterable, Codable, Sendable {
    case mesh, flow, waves, orbs, rings, dunes, contour, silk, aurora, bauhaus, blobs

    /// What the style looks like, for the settings window.
    public var summary: String {
        switch self {
        case .mesh: "Soft glows over a dark base"
        case .flow: "Marbled, slowly folding colour"
        case .waves: "Layered ribbons with a lit rim"
        case .orbs: "Lit spheres"
        case .rings: "Bands round an off-screen centre"
        case .dunes: "Stacked hills fading into haze"
        case .contour: "Topographic lines"
        case .silk: "Twisting ribbons with a sheen"
        case .aurora: "Curtains of light"
        case .bauhaus: "A grid of quarter and half circles"
        case .blobs: "A lava lamp"
        }
    }

    func shader(_ p: Palette, _ rng: inout RNG, _ frame: Frame) -> Shader {
        switch self {
        case .mesh: Self.mesh(p, &rng, frame)
        case .flow: Self.flow(p, &rng)
        case .waves: Self.waves(p, &rng)
        case .orbs: Self.orbs(p, &rng, frame)
        case .rings: Self.rings(p, &rng, frame)
        case .dunes: Self.dunes(p, &rng)
        case .contour: Self.contour(p, &rng, frame)
        case .silk: Self.silk(p, &rng, frame)
        case .aurora: Self.aurora(p, &rng)
        case .bauhaus: Self.bauhaus(p, &rng, frame)
        case .blobs: Self.blobs(p, &rng, frame)
        }
    }
}

/// Where a pixel is: `u` and `v` run 0…1 across and down; `ux` is `u` times the aspect ratio, so a circle in
/// (`ux`, `v`) is round on screen.
struct Pixel {
    let u: Float
    let v: Float
    let ux: Float
}

/// The picture's shape: its aspect ratio, how far one pixel is in `v`, and how many pixels make a point.
struct Frame: Sendable {
    let aspect: Float
    let pixel: Float
    let scale: Float
}

typealias Shader = @Sendable (Pixel) -> RGB

private let tau: Float = 6.28

extension Style {
    /// Soft radial glows over the base, the technique of curb's site.
    static func mesh(_ p: Palette, _ rng: inout RNG, _ frame: Frame) -> Shader {
        let roles = [2, 3, 2, 3, 4, 1]
        let glows = roles.map { role in
            let cx = rng.uniform(-0.1, frame.aspect + 0.1), cy = rng.uniform(-0.1, 1.1)
            let r = 0.3 + rng.unit() * 0.45
            let a = (p.isDark ? 0.7 : 0.75) * rng.uniform(0.45, 1)
            return (cx: cx, cy: cy, r: r, a: a, color: p[role])
        }
        let base = p.base
        return { px in
            var c = base
            for g in glows {
                let dx = px.ux - g.cx, dy = px.v - g.cy
                let d2 = (dx * dx + dy * dy) / (g.r * g.r)
                c = mix(c, g.color, g.a * exp(-d2 * 2.2))
            }
            return c
        }
    }

    /// Domain-warped noise through the palette: marbling.
    static func flow(_ p: Palette, _ rng: inout RNG) -> Shader {
        let qx = FBM(freq: 1, octaves: 3, rng: &rng), qy = FBM(freq: 1, octaves: 3, rng: &rng)
        let f = FBM(freq: 1, octaves: 3, rng: &rng)
        let ramp = p.ramp(p.isDark ? [0, 1, 3, 2, 4] : [0, 4, 3, 2, 1])
        let dark = p.isDark, base = p.base
        return { px in
            let wx = qx(px.u, px.v), wy = qy(px.u + 5.2, px.v + 1.3)
            let t = smooth(0.25, 0.8, f(px.u + 1.1 * wx, px.v + 1.1 * wy))
            let c = ramp(t)
            return dark ? mix(c, base, 0.45 * smooth(0.2, 0.9, px.v)) : c
        }
    }

    /// Layered ribbons, back to front, each with a lit rim and a shadow on the one behind.
    static func waves(_ p: Palette, _ rng: inout RNG) -> Shader {
        let n = 6
        let colors = p.ramp(p.isDark ? [1, 3, 2, 4] : [4, 3, 2, 1])
        let layers = (0 ..< n).map { i in
            let ph = rng.unit() * tau, fr = rng.uniform(1.2, 2.6)
            return (base: 0.25 + Float(i) * 0.12, ph: ph, fr: fr, color: colors(Float(i) / Float(n - 1)))
        }
        let sky = p.ramp(p.isDark ? [0, 1] : [0, 4])
        let dark = p.isDark, base = p.base
        return { px in
            var c = sky(px.v * 0.9)
            for l in layers {
                let y0 = l.base + 0.07 * sin(px.ux * l.fr + l.ph) + 0.04 * sin(px.ux * l.fr * 2.3 + l.ph * 1.7)
                let dy = px.v - y0
                if dy < 0 {
                    c = mix(c, .black, exp(dy / 0.03) * (dark ? 0.35 : 0.12))
                    continue
                }
                let body = smooth(0, 0.004, dy)
                let layer = dark
                    ? l.color * (1 - 0.35 * smooth(0, 0.35, dy))
                    : mix(l.color, base, 0.3 * smooth(0, 0.4, dy))
                let rim = exp(-(dy / 0.006) * (dy / 0.006)) * (dark ? 0.35 : 0.5)
                c = mix(c, layer, body)
                c = mix(c, .white, rim * body)
            }
            return c
        }
    }

    /// Large spheres lit from the top left, glowing onto the mesh behind them.
    static func orbs(_ p: Palette, _ rng: inout RNG, _ frame: Frame) -> Shader {
        let backdrop = mesh(p, &rng, frame)
        let dim: Float = p.isDark ? 0.6 : 1
        let orbs = (0 ..< 5).map { _ in
            let cx = rng.uniform(0.1, frame.aspect - 0.1), cy = rng.uniform(0.1, 0.9), r = rng.uniform(0.12, 0.34)
            return (cx: cx, cy: cy, r: r, color: p[rng.int(2, 5)])
        }
        let shadowSide: Float = p.isDark ? 0.35 : 0.75
        return { px in
            var c = backdrop(px) * dim
            for o in orbs {
                let d = hypot(px.ux - o.cx, px.v - o.cy)
                let inside = smooth(o.r + 0.003, o.r - 0.003, d)
                let lx = o.cx - o.r * 0.35, ly = o.cy - o.r * 0.4
                let ld = hypot(px.ux - lx, px.v - ly) / (o.r * 0.9)
                let sphere = mix(o.color * shadowSide, simd_min(o.color * 1.25, .white), exp(-ld * ld))
                let glow = exp(-max(d - o.r, 0) / 0.05) * (1 - inside) * 0.25
                c = mix(c, o.color, glow)
                c = mix(c, sphere, inside * 0.92)
            }
            return c
        }
    }

    /// Concentric bands round a centre below one of the bottom corners, each shaded like a cylinder.
    static func rings(_ p: Palette, _ rng: inout RNG, _ frame: Frame) -> Shader {
        let cx: Float = rng.unit() < 0.5 ? -0.2 : frame.aspect + 0.2, cy = rng.uniform(0.9, 1.4)
        let ramp = p.ramp(p.isDark ? [1, 3, 2, 4, 1] : [4, 3, 2, 1, 4])
        let dark = p.isDark, base = p.base
        return { px in
            let d = hypot(px.ux - cx, px.v - cy)
            let k = d / 0.11
            let index = k.rounded(.down)
            let shade = 0.55 + 0.45 * sin((k - index) * .pi)
            let c = ramp(index.truncatingRemainder(dividingBy: 9) / 8) * (dark ? shade : 0.8 + 0.2 * shade)
            return mix(c, base, dark ? 0.65 * smooth(0.6, 2.4, d) : 0.5 * smooth(0.8, 2.6, d))
        }
    }

    /// Hills stacked towards the viewer, each lit along its ridge and casting a shadow up the one behind.
    static func dunes(_ p: Palette, _ rng: inout RNG) -> Shader {
        let n = 7
        let colors = p.ramp(p.isDark ? [4, 3, 2, 1, 0] : [3, 2, 1, 4, 0])
        let hills = (0 ..< n).map { i in
            (ridge: FBM(freq: 2, octaves: 3, rng: &rng), i: Float(i), color: colors(Float(i) / Float(n - 1)))
        }
        let sky = p.ramp(p.isDark ? [1, 0] : [4, 0])
        return { px in
            var c = sky(px.v)
            for h in hills {
                let y0 = 0.3 + h.i * 0.1 + 0.16 * (h.ridge(px.ux * 0.4 + h.i * 3.1, h.i * 0.7) - 0.5)
                let dy = px.v - y0
                if dy < 0 {
                    c = mix(c, .black, exp(dy / 0.04) * 0.25)
                    continue
                }
                let lit = mix(simd_min(h.color * 1.3 + 0.03, .white), h.color, smooth(0, 0.12, dy))
                c = mix(c, lit, smooth(0, 0.003, dy))
            }
            return c
        }
    }

    /// Topographic lines, every fifth one stronger, over a dimmed mesh. Lines are about a point wide at any scale.
    static func contour(_ p: Palette, _ rng: inout RNG, _ frame: Frame) -> Shader {
        let backdrop = mesh(p, &rng, frame)
        let f = FBM(freq: 2, octaves: 4, rng: &rng)
        let dim: Float = p.isDark ? 0.55 : 1
        let line = p.isDark ? p[2] : p[1] * 0.6
        let step = frame.pixel * frame.scale // one point, in u and v
        return { px in
            let levels = f(px.u * 1.2, px.v * 1.2) * 26
            let gx = f((px.u + step / frame.aspect) * 1.2, px.v * 1.2) * 26 - levels
            let gy = f(px.u * 1.2, (px.v + step) * 1.2) * 26 - levels
            let nearest = levels.rounded()
            let width = max(hypot(gx, gy), 1e-4)
            let on = smooth(1.1, 0.2, abs(levels - nearest) / width)
            let major = Int(nearest) % 5 == 0
            return mix(backdrop(px) * dim, line, on * (major ? 0.55 : 0.22))
        }
    }

    /// Three wide ribbons that twist as they cross the screen, a sheen running across each.
    static func silk(_ p: Palette, _ rng: inout RNG, _ frame: Frame) -> Shader {
        let backdrop = mesh(p, &rng, frame)
        let ribbons = (0 ..< 3).map { j in (j: Float(j), ph: rng.unit() * tau, fr: rng.uniform(1.0, 2.0)) }
        let ramp = p.ramp(p.isDark ? [2, 3, 4] : [3, 2, 1])
        let dark = p.isDark
        return { px in
            var c = backdrop(px) * (dark ? 0.7 : 1)
            for r in ribbons {
                let centre = 0.3 + r.j * 0.2 + 0.18 * sin(px.ux * r.fr + r.ph)
                let angle = px.ux * 1.3 + r.ph * 0.5 + r.j
                let w = 0.06 + 0.07 * abs(sin(angle))
                let t = (px.v - centre) / w + 0.5
                let on = smooth(-0.01, 0.02, t) * smooth(1.01, 0.98, t)
                let sheen = 0.5 + 0.5 * cos((t - 0.5 + 0.3 * cos(angle)) * .pi * 1.4)
                let color = ramp(px.u)
                let ribbon = dark ? color * (0.35 + 0.75 * sheen) : mix(color * 0.82, .white, sheen * 0.7)
                let below = (px.v - centre - w * 0.6) / 0.05
                c = mix(c, .black, (dark ? 0.25 : 0.08) * exp(-below * below) * (1 - on))
                c = mix(c, ribbon.clamped, on * 0.95)
            }
            return c
        }
    }

    /// Curtains of light hanging from wandering lines, streaked by noise.
    static func aurora(_ p: Palette, _ rng: inout RNG) -> Shader {
        let curtains = (0 ..< 3).map { j in
            (
                j: Float(j),
                line: FBM(freq: 2, octaves: 3, rng: &rng),
                streak: FBM(freq: 7, octaves: 4, rng: &rng),
                ramp: p.ramp(j % 2 == 0 ? [2, 3] : [3, 4])
            )
        }
        let sky = p.isDark ? Ramp([p[0], p[1] * 0.6 + p[0] * 0.4]) : p.ramp([4, 0])
        let dark = p.isDark
        return { px in
            var c = sky(px.v)
            for k in curtains {
                let cy = 0.35 + k.j * 0.12 + 0.24 * (k.line(px.ux * 0.5 + k.j, k.j) - 0.5)
                let streak = k.streak(px.ux * 0.37 + k.j * 0.31 + 0.02 * px.v, k.j * 0.2)
                let above = max(cy - px.v, 0), below = max(px.v - cy, 0)
                let curtain = exp(-above / 0.25) * exp(-below / 0.03) * (0.4 + 1.2 * streak * streak)
                let color = k.ramp(above / 0.35)
                c = dark ? c + color * curtain * 0.8 : mix(c, color, min(curtain * 0.8, 1))
            }
            return c.clamped
        }
    }

    /// A six by four grid, each cell a quarter circle, a half circle or a disc on a plain or coloured ground.
    static func bauhaus(_ p: Palette, _ rng: inout RNG, _ frame: Frame) -> Shader {
        let cols = 6, rows = 4
        let cw = frame.aspect / Float(cols), ch: Float = 1 / Float(rows)
        let cells = (0 ..< cols * rows).map { _ in
            let color = p[rng.int(1, 5)]
            let ground = rng.unit() < 0.5 ? p[rng.int(0, 5)] : p[0]
            return (color: color, ground: ground, kind: rng.int(0, 3), corner: rng.int(0, 4))
        }
        let dark = p.isDark, base = p.base
        return { px in
            let gx = min(max(Int(px.ux / cw), 0), cols - 1), gy = min(max(Int(px.v / ch), 0), rows - 1)
            let cell = cells[gy * cols + gx]
            let x0 = Float(gx) * cw, y0 = Float(gy) * ch
            let ox = x0 + (cell.corner == 1 || cell.corner == 2 ? cw : 0)
            let oy = y0 + (cell.corner >= 2 ? ch : 0)
            let d: Float = switch cell.kind {
            case 0: hypot(px.ux - ox, px.v - oy) / min(cw, ch)
            case 1: hypot(px.ux - (x0 + cw / 2), px.v - oy) / (cw / 2)
            default: hypot(px.ux - (x0 + cw / 2), px.v - (y0 + ch / 2)) / (min(cw, ch) * 0.42)
            }
            let shape = smooth(1.003, 0.997, d)
            let lit = dark
                ? cell.color * (0.75 + 0.25 * (1 - d))
                : mix(cell.color, .white, 0.25 * (1 - min(max(d, 0), 1)))
            let c = mix(cell.ground * (dark ? 0.9 : 1), lit, shape)
            return dark ? mix(c, base, 0.35) : c
        }
    }

    /// Metaballs: Gaussian blobs summed and cut at a level, lit from within, glowing at the edge.
    static func blobs(_ p: Palette, _ rng: inout RNG, _ frame: Frame) -> Shader {
        let balls = (0 ..< 9).map { _ in
            let cx = rng.uniform(0, frame.aspect), cy = rng.uniform(0, 1), r = rng.uniform(0.08, 0.2)
            return (cx: cx, cy: cy, r2: r * r)
        }
        let ground = p.ramp(p.isDark ? [0, 1] : [0, 4])
        let ramp = p.ramp(p.isDark ? [2, 3, 4] : [3, 2, 1])
        let dark = p.isDark
        return { px in
            var field: Float = 0
            for b in balls {
                let dx = px.ux - b.cx, dy = px.v - b.cy
                field += exp(-(dx * dx + dy * dy) / b.r2)
            }
            field *= 2.2
            let inside = smooth(0.97, 1.03, field)
            let color = ramp(px.u * 0.8 + px.v * 0.2)
            let depth = smooth(1, 3.5, field)
            let blob = dark
                ? mix(color * 0.55, simd_min(color * 1.15, .white), depth)
                : mix(color, .white, depth * 0.5)
            let glow = exp(-max(1 - field, 0) * 4) * (1 - inside) * (dark ? 0.35 : 0.2)
            return mix(mix(ground(px.v), color, glow), blob, inside)
        }
    }
}
