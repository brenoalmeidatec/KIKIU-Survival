# Painel ao vivo do Claude (Alisson, PC)

Mostra em tempo (quase) real o que o Claude e os agentes dele estão fazendo. Esta branch (`painel-ao-vivo`) tem sempre 1
commit e é reescrita a cada ~20 s enquanto ele trabalha. Para acompanhar:

```
python seguir.py
```

(baixe só o `seguir.py` desta branch; ele clona a vitrine em `./kikiu-painel`, abre o painel no navegador e atualiza a cada
15 s). Se o painel mostrar "parado", o Claude não está trabalhando agora.
