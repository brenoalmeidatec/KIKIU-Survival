# Diagnóstico sanitizado do robô de playtest (#137)

Na Floresta, o limite inferior andável termina em `y=1470`; a faixa de steering começa em `y=1420`. Na execução repetida de Nicão, Floresta, semente 1 e dificuldade Fácil, o herói passou 138,6 s de jogo alternando em torno de `y=1420` (aprox. `1419,49–1421,21`) enquanto a entrada vertical mudava de sinal. O alvo ficava acima e a fuga resultante apontava para baixo. As quatro direções cardinais estavam livres na posição amostrada, o inimigo mais próximo estava a cerca de 66 px e não havia hit-stop ativo.

A causa era o corte do componente de fuga antes da soma com o alvo. Ao entrar e sair da faixa, o componente vertical alternava entre fuga ativa e fuga zerada; a soma trocava de sentido e formava um ciclo junto ao limiar. O conserto projeta a soma final contra componentes que apontam para fora e preserva o restante. Se a projeção zera, usa uma tangente cardinal determinística, sem restaurar a direção normal que cruzaria o limiar no quadro seguinte.

O detector de travamento não foi alterado. Ele continua conferindo o deslocamento entre amostras de posição a cada 30 s e acusa `heroi_preso` quando o deslocamento é menor que 6 px. Esse sinal identifica retorno ou proximidade entre os extremos do intervalo; sozinho, não prova imobilidade contínua durante todo o intervalo.
