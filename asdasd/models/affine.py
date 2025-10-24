def affine_encrypt(text, key, m):
    a = int(m)
    b = int(key)
    return ''.join(chr((a * ord(c) + b) % 256) for c in text)

def affine_decrypt(text, key, m):
    a = int(m)
    b = int(key)
    a_inv = pow(a, -1, 256)  # nghịch đảo modulo 256
    return ''.join(chr((a_inv * (ord(c) - b)) % 256) for c in text)
