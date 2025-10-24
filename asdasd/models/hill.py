import numpy as np

def text_to_vec(text):
    return [ord(c) for c in text]

def vec_to_text(vec):
    return ''.join(chr(v % 256) for v in vec)

def hill_encrypt(text, key, m=None):
    # key = "a b c d"
    k = list(map(int, key.split()))
    mat = np.array(k).reshape(2, 2)
    data = text_to_vec(text)
    if len(data) % 2 != 0:
        data.append(0)
    res = []
    for i in range(0, len(data), 2):
        block = np.array(data[i:i+2])
        enc = mat.dot(block) % 256
        res.extend(enc)
    return vec_to_text(res)

def hill_decrypt(text, key, m=None):
    k = list(map(int, key.split()))
    mat = np.array(k).reshape(2, 2)
    inv = np.linalg.inv(mat)
    det = int(round(np.linalg.det(mat)))
    det_inv = pow(det, -1, 256)
    adj = det * inv
    mat_inv = (det_inv * adj) % 256
    data = text_to_vec(text)
    res = []
    for i in range(0, len(data), 2):
        block = np.array(data[i:i+2])
        dec = mat_inv.dot(block) % 256
        res.extend(dec)
    return vec_to_text(res)
