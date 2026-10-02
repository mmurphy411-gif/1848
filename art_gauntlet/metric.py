"""Inspectable silhouettes; uncertain reference alignment cannot veto anatomy."""
from collections import deque
from PIL import Image, ImageChops


def reference_mask(image, threshold=15):
    # Estimate paper from border pixels, rather than assuming white. Flood only
    # similar background connected to the crop boundary. Pale
    # internal markings survive; disconnected cast shadows need calibrated masks.
    im = image.convert("RGB")
    w, h = im.size
    pixels = im.load()
    border = [pixels[x,y] for x in range(w) for y in (0,h-1)] + [pixels[x,y] for y in range(h) for x in (0,w-1)]
    paper = tuple(sorted(p[c] for p in border)[len(border)//2] for c in range(3))
    background = bytearray(w * h)
    queue = deque()
    def visit(x, y):
        i = y * w + x
        if not background[i] and max(abs(pixels[x,y][c]-paper[c]) for c in range(3)) <= threshold:
            background[i] = 1
            queue.append((x, y))
    for x in range(w):
        visit(x, 0)
        visit(x, h - 1)
    for y in range(h):
        visit(0, y)
        visit(w - 1, y)
    while queue:
        x, y = queue.popleft()
        for a, b in ((x-1,y), (x+1,y), (x,y-1), (x,y+1)):
            if 0 <= a < w and 0 <= b < h:
                visit(a, b)
    # Keep the largest connected foreground, excluding detached caption text and
    # cast shadows. This is a proposal mask: thin fins and pale edges need review.
    remaining = bytearray(0 if b else 1 for b in background)
    largest = []
    for start in range(w*h):
        if not remaining[start]:
            continue
        remaining[start] = 0
        component = [start]
        cursor = 0
        while cursor < len(component):
            i = component[cursor]
            cursor += 1
            x, y = i%w, i//w
            for nx,ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                j = ny*w+nx
                if 0 <= nx < w and 0 <= ny < h and remaining[j]:
                    remaining[j] = 0
                    component.append(j)
        if len(component) > len(largest):
            largest = component
    result = bytearray(w*h)
    for i in largest:
        result[i] = 255
    return Image.frombytes("L", (w,h), bytes(result))


def normalize(mask, size=384):
    mask = mask.convert("L").point(lambda p: 255 if p >= 128 else 0)
    box = mask.getbbox()
    if box is None:
        raise ValueError("Empty silhouette")
    subject = mask.crop(box)
    # Fixed square canvas, uniform height alignment; reject overflow rather than
    # silently clipping wide subjects (side-on trout).
    scale = (size - 32) / subject.height
    width = round(subject.width * scale)
    canvas = Image.new("L", (max(size, width + 32), size))
    subject = subject.resize((max(1, width), size - 32), Image.Resampling.NEAREST)
    canvas.paste(subject, ((canvas.width-subject.width)//2, 16))
    return canvas


def compare(reference, candidate):
    a, b = normalize(reference), normalize(candidate)
    width = max(a.width, b.width)
    aligned = []
    for im in (a, b):
        target = Image.new("L", (width, a.height))
        target.paste(im, ((width-im.width)//2, 0))
        aligned.append(target)
    a, b = aligned
    def iou(x, y):
        intersection = sum(ImageChops.darker(x, y).histogram()[128:])
        union = sum(ImageChops.lighter(x, y).histogram()[128:])
        return intersection / union if union else 1.0
    # Symmetric boundary distance via a linear-time 8-neighbor distance transform.
    def outline(im):
        from PIL import ImageFilter
        return ImageChops.subtract(im, im.filter(ImageFilter.MinFilter(3)))
    def distances(im):
        w, h = im.size
        d = [0.0 if p else float(w+h) for p in im.tobytes()]
        for y in range(h):
            for x in range(w):
                i = y*w+x
                if x: d[i] = min(d[i], d[i-1]+1)
                if y: d[i] = min(d[i], d[i-w]+1)
                if x and y: d[i] = min(d[i], d[i-w-1]+1.41421356)
                if x+1 < w and y: d[i] = min(d[i], d[i-w+1]+1.41421356)
        for y in range(h-1, -1, -1):
            for x in range(w-1, -1, -1):
                i = y*w+x
                if x+1 < w: d[i] = min(d[i], d[i+1]+1)
                if y+1 < h: d[i] = min(d[i], d[i+w]+1)
                if x+1 < w and y+1 < h: d[i] = min(d[i], d[i+w+1]+1.41421356)
                if x and y+1 < h: d[i] = min(d[i], d[i+w-1]+1.41421356)
        return d
    oa, ob = outline(a), outline(b)
    da, db = distances(oa), distances(ob)
    ab = [db[i] for i,p in enumerate(oa.tobytes()) if p]
    ba = [da[i] for i,p in enumerate(ob.tobytes()) if p]
    return {"iou": iou(a,b), "outline_distance_height": (sum(ab)/len(ab)+sum(ba)/len(ba))/2/(a.height-32),
            "vertical_thirds": [iou(a.crop((0, y*a.height//3, width, (y+1)*a.height//3)), b.crop((0, y*a.height//3, width, (y+1)*a.height//3))) for y in range(3)]}


def disposition(values, previous, references, tolerance=0.01, blind_to_metric=False):
    if not previous or blind_to_metric:
        return "review"
    regressions = [v for v in values if values[v]["iou"] < previous[v]["iou"] - tolerance]
    if any(references[v].get("calibrated") and references[v].get("confidence") == "high" for v in regressions):
        return "metric_rejected"
    if regressions:
        return "review_tradeoff"
    return "review" if any(values[v]["iou"] > previous[v]["iou"] + .001 for v in values) else "search_only"
