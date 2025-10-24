alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

def substitution_encrypt(text, key, m=None):
    mapping = str.maketrans(alphabet, key.upper())
    return text.upper().translate(mapping)

def substitution_decrypt(text, key, m=None):
    mapping = str.maketrans(key.upper(), alphabet)
    return text.upper().translate(mapping)
