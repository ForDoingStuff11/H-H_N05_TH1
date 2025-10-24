def vigenere_encrypt(text, key, m=None):
    res = ""
    for i, c in enumerate(text):
        res += chr((ord(c) + ord(key[i % len(key)])) % 256)
    return res

def vigenere_decrypt(text, key, m=None):
    res = ""
    for i, c in enumerate(text):
        res += chr((ord(c) - ord(key[i % len(key)])) % 256)
    return res
