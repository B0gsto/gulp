"""The Fish family body: one parametric teardrop and one topology that every Fish species is made
from (docs/07-asset-list.md M_Species_Base_Fish; docs/06-art-bible.md sections 3.1, 5.4 and 6.5).
The family base (families/fish/build.py) is this body with the family's neutral numbers; a
species (species/minnow, later puffer, shark) is the same body with its own numbers. Because
every species is lofted by `FishBody.part`, they all share the ring and segment layout, and the
rig fit and skin weights (rigs.FishFit) are functions of the body, so they cannot drift apart.

Profile, at station y from the nose (t = 0) to the tail root (t = 1):
  top(y), bot(y)   height of the back over the centre line and depth of the belly under it
  half_w(y)        half width
  section(y, a)    the point at angle a around the body (0 on the back, pi on the belly)

Topology (the family standard): `segs` segments around (a multiple of four, so a vertex line runs
along the back, the belly and both flanks: the mouth's lip line and the UV seams sit on them) and
`rings` rings along: closer together at the nose, where the head's curvature is; from the first
spine weight node (SPINE_NODES below) to the tail root a ring on every node, so an edge loop sits
wherever the skin hands over from one bone to the next, and the rings between nodes evenly spaced,
so a pose's stretch and bend spread over even bands (ring_stations). Two pole fans close the ends.
All quads in between.
"""
import math

try:                        # Blender; the size constants also load in the system python3 (placeholder.py)
    from mathutils import Vector
except ImportError:
    Vector = None

# The one place the family's sizes live. The Minnow is the family's size reference and the base is
# built at the same size (06 section 6.2 as ruled: 3.0 long, 1.365 tall, 0.7 wide; body depth 47% of
# the body length, nose to tail root, inside the 45 to 55% range). Species with another size (the
# Puffer, 2.4 long) pass their own numbers; nothing else in the pipeline states a fish size.
LENGTH, HEIGHT, WIDTH = 3.0, 1.365, 0.7
DEPTH_SHARE = 0.47
Y_NOSE, Y_TAIL_TIP = -LENGTH / 2.0, LENGTH / 2.0
FIN_THICK = 0.04            # fins are closed slabs; the floor is 0.03 (06 section 6.5)

# Where each spine bone's weight is 1, as body fractions from the nose (0) to the tail root (1); the
# skin hands over between neighbours (rigs.FishFit). Spine1 is the rigid head behind the eye,
# Spine2 the girth centre, TailFin the tail root.
SPINE_NODES = (0.30, 0.55, 0.72, 0.87, 1.0)
TAIL_DENSITY = 0.3          # rings per stud at the tail root over those at the head node, less one (ring_stations)


def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


class FishBody:
    """Profile shape numbers (all fractions of the body depth or of the half width):

    nose, root      y of the nose tip and of the tail root (the body's end)
    depth           scale of the depth profile; `max_depth`, if given, solves for it
    head            share of the body (from the nose) the round head takes to reach full depth
    back            (share of depth, waist, start, power): the back line, from the head's top to
                    `waist` at the tail root, falling from `start` along the body
    belly           (share of depth, front power, waist, start, power): the belly line
    nose_drop       how far the nose tip sits below the centre line (share of depth)
    width           (half width, front power, waist, start, power) and `cheeks` (bulge, at, spread)
    square          section exponents (x, z): 1 is an ellipse, under 1 squarer flanks
    poles           how far the nose pole drops (studs) and the tail pole reaches past the root
    """

    def __init__(self, nose=-1.5, root=0.95, depth=1.0, max_depth=None, head=0.40,
                 back=(0.45, 0.25, 0.42, 1.3), belly=(0.55, 0.9, 0.22, 0.48, 1.0), nose_drop=0.02,
                 width=(0.27, 0.95, 0.2, 0.38, 1.35), cheeks=(0.04, 0.24, 0.12), square=(0.85, 0.9),
                 poles=(-0.03, 0.04)):
        self.nose, self.root, self.head = nose, root, head
        self.back, self.belly, self.nose_drop = back, belly, nose_drop
        self.width, self.cheeks, self.square, self.poles = width, cheeks, square, poles
        self.depth = 1.0
        if max_depth is not None:
            self.depth = max_depth / self.deepest()[0]
        else:
            self.depth = depth

    # -------------------------------------------------------------- profile
    @property
    def length(self):
        return self.root - self.nose

    def t(self, y):
        return min(1.0, max(0.0, (y - self.nose) / self.length))

    def y(self, t):
        return self.nose + t * self.length

    def _front(self, t):
        """A round, blunt head that blends into the body with no change of curvature."""
        u = min(1.0, t / self.head)
        return math.sqrt(max(0.0, 1.0 - (1.0 - u) ** 3))

    @staticmethod
    def _rear(t, waist, start, power):
        """The taper from the deepest point to the thin tail root."""
        u = min(1.0, max(0.0, (t - start) / (1.0 - start)))
        return waist + (1.0 - waist) * math.cos(0.5 * math.pi * u) ** power

    def top(self, y):
        t, (share, waist, start, power) = self.t(y), self.back
        f = self._front(t)
        return self.depth * (share * f * self._rear(t, waist, start, power) - self.nose_drop * (1.0 - f))

    def bot(self, y):
        t, (share, fp, waist, start, power) = self.t(y), self.belly
        f = self._front(t)
        return self.depth * (share * f ** fp * self._rear(t, waist, start, power) + self.nose_drop * (1.0 - f))

    def half_w(self, y):
        t, (hw, fp, waist, start, power) = self.t(y), self.width
        bulge, at, spread = self.cheeks
        cheeks = 1.0 + bulge * math.exp(-((t - at) / spread) ** 2)
        return hw * self._front(t) ** fp * self._rear(t, waist, start, power) * cheeks

    def half_h(self, y):
        return 0.5 * (self.top(y) + self.bot(y))

    def section(self, y, a):
        s, c = math.sin(a), math.cos(a)
        px, pz = self.square
        x = self.half_w(y) * math.copysign(abs(s) ** px, s)
        z = (self.top(y) if c >= 0.0 else self.bot(y)) * math.copysign(abs(c) ** pz, c)
        return Vector((x, y, z))

    def on_flank(self, y, z, inset):
        h = self.top(y) if z >= 0.0 else self.bot(y)
        return self.half_w(y) * math.sqrt(max(0.0, 1.0 - (z / h) ** 2)) - inset

    def deepest(self, samples=240):
        """(depth back to belly, y) of the deepest section."""
        return max((self.top(self.y(i / samples)) + self.bot(self.y(i / samples)), self.y(i / samples))
                   for i in range(samples + 1))

    def highest(self, samples=240):
        return max(self.top(self.y(i / samples)) for i in range(samples + 1))

    def lowest(self, samples=240):
        return max(self.bot(self.y(i / samples)) for i in range(samples + 1))

    # -------------------------------------------------------------- topology
    def ring_stations(self, rings, nodes=()):
        """Body fractions of the rings. The head, in front of the first weight node, keeps the
        rings of a spacing closer at the nose (its curvature); from the first node to the tail
        root every weight node (a body fraction) sits on a ring, so an edge loop is on every
        hand-over, and the rings between two nodes are evenly spaced, each span taking its share
        of the rings by length (TAIL_DENSITY more per stud at the tail root, where the body
        narrows). Even spans keep the stretch and the bend of a pose spread over the same number
        of edges per stud, so no one band takes it (weightcheck.py)."""
        n = rings + 1
        ts = [0.55 * (0.5 - 0.5 * math.cos(math.pi * k / n)) + 0.45 * (k / n) for k in range(1, rings + 1)]
        inner = [t for t in nodes if 0.0 < t < 1.0]
        if not inner:
            return ts
        head = [t for t in ts if t < inner[0] - 0.4 * (1.0 - inner[0]) / (rings - len([u for u in ts if u < inner[0]]))]
        anchors = inner + [1.0]
        free = rings - len(head) - len(inner)            # rings strictly between the nodes, and before the root
        lengths = [(b - a) * (1.0 + TAIL_DENSITY * (0.5 * (a + b) - inner[0]) / (1.0 - inner[0]))
                   for a, b in zip(anchors, anchors[1:])]
        share = [free * L / sum(lengths) for L in lengths]
        count = [int(c) for c in share]
        for i in sorted(range(len(share)), key=lambda i: count[i] - share[i])[:free - sum(count)]:
            count[i] += 1
        out = list(head)
        for (a, b), c in zip(zip(anchors, anchors[1:]), count):
            out.append(a)
            edges = c + (1.0 if b < 1.0 else 0.7)        # the last span ends at the root's pole fan, not on a ring
            out += [a + (b - a) * j / edges for j in range(1, c + 1)]
        return out

    def part(self, segs, rings, nodes=()):
        """The body as one closed quad loft with pole fans (meshgen part: verts, faces, params).
        The ring vertices are 1 .. rings * segs, ring-major, segment 0 on the back."""
        if segs % 4:
            raise ValueError("segs must be a multiple of 4 (vertex lines on back, belly and flanks)")
        import meshgen
        out = [[tuple(self.section(self.y(t), 2.0 * math.pi * j / segs)) for j in range(segs)]
               for t in self.ring_stations(rings, nodes)]
        return meshgen.loft(out, (0.0, self.nose, self.poles[0]), (0.0, self.root + self.poles[1], 0.0))


class ProfileBody(FishBody):
    """A body given by plain half-height and half-width functions (symmetric back and belly), for
    tools that loft their own simple fish (placeholder.py), so they fit the same rig and weights."""

    def __init__(self, nose, root, half_h, half_w):
        self.nose, self.root, self.depth = nose, root, 1.0
        self.square, self.poles = (1.0, 1.0), (0.0, 0.0)
        self._hh, self._hw = half_h, half_w

    def top(self, y):
        return self._hh(y)

    def bot(self, y):
        return self._hh(y)

    def half_w(self, y):
        return self._hw(y)
