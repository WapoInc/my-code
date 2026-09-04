import numpy as np
from PIL import Image

img = Image.open('/Users/vinceresente/my-code/@-Bicep/@-My-AIRS-Infra-as-Code/My-Labs/1-MngEnv461963.onmicrosoft.com/My-WWW-site/802dot1x-logo-transparent.png')
r, g, b, a = img.split()
alpha_arr = np.array(a)

# Create a binary mask restricted to x in 0..170
mask = (alpha_arr[:, 0:171] > 0).astype(int)
h, w = mask.shape

# BFS or DFS to find connected components (8-connectivity)
visited = np.zeros_like(mask, dtype=bool)

components = []

for y in range(h):
    for x in range(w):
        if mask[y, x] and not visited[y, x]:
            # Found a new component
            comp_pixels = []
            queue = [(y, x)]
            visited[y, x] = True
            while queue:
                cy, cx = queue.pop(0)
                comp_pixels.append((cy, cx))
                # 8-connectivity directions
                for dy in [-1, 0, 1]:
                    for dx in [-1, 0, 1]:
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w:
                            if mask[ny, nx] and not visited[ny, nx]:
                                visited[ny, nx] = True
                                queue.append((ny, nx))
            
            components.append(comp_pixels)

print(f"Number of connected components: {len(components)}")
for i, comp in enumerate(components, 1):
    ys = [p[0] for p in comp]
    xs = [p[1] for p in comp]
    min_y, max_y = min(ys), max(ys)
    min_x, max_x = min(xs), max(xs)
    print(f"Component {i}: bbox y=[{min_y}, {max_y}], x=[{min_x}, {max_x}] | Pixel count: {len(comp)}")

