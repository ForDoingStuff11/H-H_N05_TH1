from pyDes import des, ECB, PAD_PKCS5

def des_encrypt(text, key, m=None):
    d = des(key[:8], ECB, padmode=PAD_PKCS5)
    return d.encrypt(text).hex()

def des_decrypt(text, key, m=None):
    d = des(key[:8], ECB, padmode=PAD_PKCS5)
    return d.decrypt(bytes.fromhex(text)).decode()
