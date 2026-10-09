"""Draw a review diagram from the 23 GPS fixes supplied on 2026-10-02.

This is a visual hypothesis for review, not a replacement for surveyed marks.
"""

from math import atan2, cos, hypot, pi
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


GPS = {
    1: (37.4227303, -122.1436209), 2: (37.4226443, -122.1434394),
    3: (37.4226044, -122.1433659), 4: (37.4225624, -122.1432805),
    5: (37.4224676, -122.1431010), 6: (37.4224054, -122.1431519),
    7: (37.4223473, -122.1431958), 8: (37.4222367, -122.1432862),
    9: (37.4221851, -122.1433282), 10: (37.4222701, -122.1435301),
    11: (37.4223128, -122.1436132), 12: (37.4223620, -122.1437084),
    13: (37.4224588, -122.1438758), 14: (37.4225170, -122.1438277),
    15: (37.4225704, -122.1437841), 16: (37.4226322, -122.1437281),
    17: (37.4226850, -122.1436840), 18: (37.4227449, -122.1436425),
    19: (37.4226316, -122.1435844), 20: (37.4224662, -122.1437005),
    21: (37.4226001, -122.1436843), 22: (37.4225510, -122.1437342),
    23: (37.4225590, -122.1436476),
}

ORIGIN = GPS[13]
RADIUS = 6_371_000
XY = {
    i: ((lon - ORIGIN[1]) * pi / 180 * RADIUS * cos(ORIGIN[0] * pi / 180),
        (lat - ORIGIN[0]) * pi / 180 * RADIUS)
    for i, (lat, lon) in GPS.items()
}

# The four extreme corners are 18, 13, 9, 5. A/B is the sampled penalty end.
A, B, C, D = (XY[i] for i in (18, 13, 9, 5))
WIDTH_VECTOR = (B[0] - A[0], B[1] - A[1])
LENGTH_VECTOR = (D[0] - A[0], D[1] - A[1])
DET = WIDTH_VECTOR[0] * LENGTH_VECTOR[1] - WIDTH_VECTOR[1] * LENGTH_VECTOR[0]


def uv(index):
    x, y = XY[index]
    x -= A[0]
    y -= A[1]
    return ((x * LENGTH_VECTOR[1] - y * LENGTH_VECTOR[0]) / DET,
            (WIDTH_VECTOR[0] * y - WIDTH_VECTOR[1] * x) / DET)


def screen(u, v):
    return (170 + u * 545, 205 + v * 805)


def draw_dashed(draw, start, end, color, width=3, dash=13, gap=10):
    dx, dy = end[0] - start[0], end[1] - start[1]
    length = hypot(dx, dy)
    if length == 0:
        return
    t = 0
    while t < length:
        stop = min(t + dash, length)
        draw.line([(start[0] + dx * t / length, start[1] + dy * t / length),
                   (start[0] + dx * stop / length, start[1] + dy * stop / length)],
                  fill=color, width=width)
        t += dash + gap


def font(size):
    return ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc', size)


OUT = Path(__file__).with_name('survey_23_point_reconstruction.png')
image = Image.new('RGB', (1600, 1220), '#f4f7f5')
draw = ImageDraw.Draw(image)
title, subtitle, body, small = font(40), font(23), font(25), font(20)
draw.text((85, 55), '23 个 GPS 点：场地复原草图', font=title, fill='#173d36')
draw.text((88, 115), '橙点为现场采集；彩色线按采点拟合并居中；虚线表示依据对称关系推算',
          font=subtitle, fill='#47645d')

# Field panel and measured perimeter.
draw.rounded_rectangle((92, 165, 790, 1080), radius=30, fill='#12392f')
draw.rectangle((170, 205, 715, 1010), outline='#d7f4e4', width=5)
draw_dashed(draw, screen(0, .5), screen(1, .5), '#a9c7c0', width=3)
draw_dashed(draw, screen(.5, 0), screen(.5, 1), '#527b71', width=2, dash=7, gap=12)

# Sampled penalty front and plausible smaller area front.
pa = sorted([uv(19), uv(20)])
pa_half_width = (pa[1][0] - pa[0][0]) / 2
pa_left, pa_right = .5 - pa_half_width, .5 + pa_half_width
pa_depth = (pa[0][1] + pa[1][1]) / 2
ga = sorted([uv(21), uv(22)])
ga_half_width = (ga[1][0] - ga[0][0]) / 2
ga_left, ga_right = .5 - ga_half_width, .5 + ga_half_width
ga_depth = (ga[0][1] + ga[1][1]) / 2

draw.line([screen(pa_left, pa_depth), screen(pa_right, pa_depth)], fill='#53e4a4', width=6)
draw.line([screen(ga_left, ga_depth), screen(ga_right, ga_depth)], fill='#e3c66d', width=5)

# Same-end sides are reconstructed because their goal-line corners were not sampled.
for u in (pa_left, pa_right):
    draw_dashed(draw, screen(u, 0), screen(u, pa_depth), '#53e4a4', width=4)
for u in (ga_left, ga_right):
    draw_dashed(draw, screen(u, 0), screen(u, ga_depth), '#e3c66d', width=3)

# Reflect the sampled end about halfway. All opposite-end marks are inferred.
for left, right, depth, color, width in (
    (pa_left, pa_right, pa_depth, '#53d6e4', 4),
    (ga_left, ga_right, ga_depth, '#b6bfff', 3),
):
    front = 1 - depth
    for start, end in [((left, 1), (left, front)),
                       ((left, front), (right, front)),
                       ((right, front), (right, 1))]:
        draw_dashed(draw, screen(*start), screen(*end), color, width=width)

_, spot_v = uv(23)
for u, v, color, radius in [(.5, spot_v, '#edca67', 8),
                             (.5, 1 - spot_v, '#b6bfff', 7)]:
    x, y = screen(u, v)
    draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=color)

# Show every raw GPS fix. 18 is the closing fix near 1; neither is joined to 19.
for i in range(1, 24):
    x, y = screen(*uv(i))
    draw.ellipse((x-6, y-6, x+6, y+6), fill='#ff985c', outline='#102e28', width=2)
    if i in (1, 5, 9, 13, 18, 19, 20, 21, 22, 23):
        offset = {1: (13, 11), 18: (-37, -24), 19: (-30, -30),
                  20: (13, 12), 21: (-30, -28), 22: (12, -28),
                  23: (11, -30)}.get(i, (10, -23))
        draw.text((x + offset[0], y + offset[1]), str(i), font=small, fill='#fff8e9')

# Dimension annotations.
draw.text((355, 1026), '短边约 37.6 m', font=subtitle, fill='#d7f4e4')
draw.text((105, 590), '约 57.0 m', font=small, fill='#d7f4e4')
draw.text((341, 413), '19—20 约 21.1 m', font=small, fill='#53e4a4')

# Explanation panel.
x = 840
draw.text((x, 190), '已由坐标确认', font=font(30), fill='#173d36')
for j, line in enumerate([
    '外框四角：18 / 13 / 9 / 5',
    '点 1 与点 18 相距约 2.5 m（回到起点）',
    '19 / 20：你确认的禁区前角',
    '18 → 19 是换位，不能画成场地线',
]):
    draw.text((x, 246 + j*47), line, font=body, fill='#214940')

draw.text((x, 480), '对称复原', font=font(30), fill='#173d36')
for j, line in enumerate([
    '21 / 22：像小禁区前沿两角',
    '23：你确认的本端罚球点',
    '另一端禁区、小禁区和点位：按中线镜像补出',
    '两条禁区侧边：由前角投影到本端球门线',
    '禁区、小禁区和点球点均对齐外框几何中轴',
]):
    draw.text((x, 537 + j*47), line, font=body, fill='#546c64')

draw.rounded_rectangle((838, 835, 1520, 1045), radius=18, fill='#e5eee9')
draw.text((862, 860), '读图说明', font=font(27), fill='#173d36')
draw.text((862, 910), '橙点保留原坐标；细虚线是几何中轴。', font=body, fill='#47645d')
draw.text((862, 950), '补线强制居中，不代表实测标线已居中。', font=body, fill='#47645d')
draw.text((862, 990), '中圈半径尚无采点，本图不补画。', font=body, fill='#47645d')

image.save(OUT)
print(OUT)
