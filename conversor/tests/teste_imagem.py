"""Confere a porta Python do montar-idf/imagem-derivada: remontar imagens já criadas pelo PowerShell tem que dar a
mesma seleção de EPMs/FPMs e o mesmo tamanho. Não grava nada no ELIAS. Uso (WSL): python3 teste_imagem.py v46 v43 v35"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'app'))
import imagem  # noqa: E402

falhou = False
for v in sys.argv[1:] or ['v46']:
    antes = imagem._json(imagem.DIAG / f'idf-populos-{v}.json')
    epms, fpms = imagem.selecao_derivada(v)
    novo, _, nao = imagem.montar(f'populos-elux7-{v}', epms, fpms)
    a, b = imagem._sel(antes), imagem._sel(novo)
    ok = a == b
    falhou |= not ok
    print(v, 'IGUAL' if ok else 'DIFERENTE', f'{len(b)} pacotes', round(novo['imageSize'] / 1048576), 'MB',
          f'(antes {round((antes.get("imageSize") or 0) / 1048576)} MB)', '' if ok else f'só antes: {sorted(a - b)[:5]} só novo: {sorted(b - a)[:5]}')
sys.exit(1 if falhou else 0)
