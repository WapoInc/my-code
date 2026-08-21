import numpy as np
from PIL import Image

img = Image.open('/Users/vinceresente/my-code/@-Bicep/@-My-AIRS-Infra-as-Code/My-Labs/1-MngEnv461963.onmicrosoft.com/My-WWW-site/802dot1x-logo-transparent.png')
r, g, b, a = img.split()
alpha = np.array(a)[:, 0:171]

# Let's inspect rows to find where there are gaps inside the mask.
# Specifically, we want to see if we can find the boundaries of the "shield" and the "triangle" / "IEEE" component inside.
# If we do a connected component analysis on the INVERTED mask (background is 1, mask is 0), we find the holes inside.
inverted_mask = (alpha == 0).astype(int)
h, w = inverted_mask.shape

visited = np.zeros_like(inverted_mask, dtype=bool)
holes = []
for y in range(h):
    for x in range(w):
        if inverted_mask[y, x] and not visited[y, x]:
            comp_pixels = []
            queue = [(y, x)]
            visited[y, x] = True
            while queue:
                cy, cx = queue.pop(0)
                comp_pixels.append((cy, cx))
                for dy, dx in [(-1,0),(1,0),(0,-1),(0,1)]:
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w:
                        if inverted_mask[ny, nx] and not visited[ny, nx]:
                            visited[ny, nx] = True
                            queue.append((ny, nx))
            holes.append(comp_pixels)

# Exclude the background component (the one that touches the borders)
inner_holes = []
for hole in holes:
    ys = [p[0] for p in hole]
    xs = [p[1] for p in hole]
    min_y, max_y = min(ys), max(ys)
    min_x, max_x = min(xs), max(xs)
    if min_y > 0 and max_y < h-1 and min_x > 0 and max_x < w-1:
        inner_holes.append(hole)

print(f"Number of inner holes (empty spaces/gaps inside the active region): {len(inner_holes)}")
for i, hole in enumerate(inner_holes, 1):
    ys = [p[0] for p in hole]
    xs = [p[1] for p in hole]
    print(f"Hole {i}: bbox y=[{min(ys)}, {max(ys)}], x=[{min(xs)}, {max(xs)}] | Pixels: {len(hole)}")

