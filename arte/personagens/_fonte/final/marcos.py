"""Landmarks do rosto (mediapipe FaceLandmarker, 478 pontos) nas fotos de cada personagem."""
import cv2, numpy as np
import mediapipe as mp
from mediapipe.tasks.python import vision, BaseOptions
U = '/root/.claude/uploads/6ba9e05a-030f-5eb6-bf76-b30a73755dea/'
FOTOS = {'nicao': '68d0401f-image.png', 'lucas': '8d63d3bd-image.png', 'joao': 'c008d1a9-image.png',
         'matheus': 'c2dbba9f-image.png', 'beto': '3e139a59-image.png', 'lukako': 'ac0a8833-image.png',
         'fabio': '47084391-image.png', 'breno': '263f2728-image.png'}
_det = None
def marcos(nome):
    global _det
    if _det is None:
        _det = vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
            base_options=BaseOptions(model_asset_path='face_landmarker.task', delegate=BaseOptions.Delegate.CPU), num_faces=4))
    img = cv2.imread(U + FOTOS[nome]); s = min(1.0, 1200 / max(img.shape[:2]))
    if s < 1: img = cv2.resize(img, None, fx=s, fy=s, interpolation=cv2.INTER_AREA)
    r = _det.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))))
    H, W = img.shape[:2]
    faces = [np.array([[p.x * W, p.y * H] for p in f]) for f in r.face_landmarks]
    if not faces: return img, None
    return img, max(faces, key=lambda a: np.ptp(a[:, 0]))
if __name__ == '__main__':
    for n in FOTOS:
        img, f = marcos(n)
        if f is not None:
            v = img.copy()
            for (x, y) in f[::3]: cv2.circle(v, (int(x), int(y)), 1, (0, 255, 0), -1)
            x0, y0 = f.min(0).astype(int); x1, y1 = f.max(0).astype(int)
            cv2.imwrite(f'lm_{n}.png', v[max(0, y0 - 60):y1 + 30, max(0, x0 - 40):x1 + 40])
        print(n, img.shape, None if f is None else f.min(0).round())
