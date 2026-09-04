import numpy as np
from PIL import Image

img = Image.open('/Users/vinceresente/my-code/@-Bicep/@-My-AIRS-Infra-as-Code/My-Labs/1-MngEnv461963.onmicrosoft.com/My-WWW-site/802dot1x-logo-transparent.png')
r, g, b, a = img.split()
np_a = np.array(a)

# Let's see what components exist if we ignore very faint alpha values.
# Let's plot or print out a small representation of the alpha channel 
# to understand what components are actually there.
# Let's look at the alpha values along the columns or rows.
print("Check some rows at different regions to distinguish shield vs IEEE component")
# The query mentions: "Goal is to distinguish the current IEEE component from shield and find space immediately below triangle."
# Let's find where the shield borders are, and where "IEEE" or "triangle" lies.
# Let's do a connected component analysis where we filter out low alpha, e.g., alpha > 50 or 100 or 200, to see if they separate.

for threshold in [0, 50, 100, 200]:
    mask = (np_a[:, 0:171] > threshold).astype(int)
    h, w = mask.shape
    visited = np.zeros_like(mask, dtype=bool)
    components = []
    for y in range(h):
        for x in range(w):
            if mask[y, x] and not visited[y, x]:
                comp_pixels = []
                queue = [(y, x)]
                visited[y, x] = True
                while queue:
                    cy, cx = queue.pop(0)
                    comp_pixels.append((cy, cx))
                    for dy, dx in [(-1,0),(1,0),(0,-1),(0,1)]:
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w:
                            if mask[ny, nx] and not visited[ny, nx]:
                                visited[ny, nx] = True
                                queue.append((ny, nx))
                components.append(comp_pixels)
    # Filter out very small components (e.g., < 10 pixels)
    large_components = [c for c in components if len(c) >= 10]
    print(f"Threshold > {threshold}: {len(large_components)} large components (>= 10 pixels)")
    for i, comp in enumerate(large_components, 1):
        ys = [p[0] for p in comp]
        xs = [p[1] for p in comp]
        print(f"  Comp {i}: bbox y=[{min(ys)}, {max(ys)}], x=[{min(xs)}, {max(xs)}] | Pixels: {len(comp)}")

