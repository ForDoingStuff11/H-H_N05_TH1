def permutation_encrypt(text, key, m):
    order = list(map(int, m.split()))
    block_size = len(order)
    res = ""
    for i in range(0, len(text), block_size):
        block = list(text[i:i+block_size])
        if len(block) < block_size:
            block += [' '] * (block_size - len(block))
        permuted = ''.join(block[j-1] for j in order)
        res += permuted
    return res

def permutation_decrypt(text, key, m):
    order = list(map(int, m.split()))
    block_size = len(order)
    inverse = [0]*block_size
    for i, j in enumerate(order):
        inverse[j-1] = i
    res = ""
    for i in range(0, len(text), block_size):
        block = list(text[i:i+block_size])
        res += ''.join(block[j] for j in inverse)
    return res
