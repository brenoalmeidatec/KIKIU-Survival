# Viabilidade: núcleo da horda em C++ (GDExtension) para o PC

Pesquisa só de leitura. Nada foi alterado no repositório. Data: 2026-10-08.

## Estado atual (o que foi lido)

- Projeto PC: `E:\Dev\KIKIU\jogos\hordas\projeto` (Godot 4.4, renderer GL Compatibility). O caminho `E:\Dev\KIKIU-Vita\fonte_main\...` citado no pedido não existe nesta máquina; o equivalente está em `E:\Dev\KIKIU`.
- `export_presets.cfg` tem **um único preset**: `Windows Desktop`, `x86_64`, `embed_pck=true`, `export_path="../build/KIKIU.exe"`, `modify_resources=true` (precisa do rcedit).
- Não há preset Linux nem macOS. O README só anuncia Windows. O port PS Vita é projeto à parte (godot-vita 3.5, `jogos/hordas-vita`).
- Instalador: `jogos/hordas/instalador/kikiu.iss` (Inno Setup 6, por usuário, em `%LOCALAPPDATA%\Programs\KIKIU`), gerado por `jogos/hordas/gerar_instalador.sh`. Saída em `build/` (fora do Git). Não há zip de release no fluxo atual.
- Não existe nenhum `.gdextension`, nem `godot-cpp`, nem DLL no projeto PC. O GDScript só tem a classe interna `class V` em `scripts/hordas/inimigos.gd` (linha 28); não há referência a `NucleoHorda` nem a `class_exists` no PC.
- Fonte C++ (Godot 3, em `E:\Dev\KIKIU-Vita\repo\jogos\hordas-vita\modulo\horda_vita\`): `nucleo_horda.h` (130 linhas) e `nucleo_horda.cpp` (367 linhas), mais `register_types.cpp`, `SCsub`, `config.py`. `horda_vita.cpp` e `vita_hw.cpp` são do Vita e não entram no núcleo.

## 1. O que muda para virar GDExtension (Godot 4.4 / godot-cpp 4.4)

Não é renomeação simples. GDNative/NativeScript (Godot 3) e GDExtension (Godot 4) têm sistemas de registro diferentes. A lógica (`passo`, grade, separação, integração) pode ser preservada quase toda; o que muda é cabeçalho, tipos de array, base da classe e registro.

Trocas de API necessárias no `nucleo_horda.h/.cpp` (lista para aplicar):

| Godot 3 (módulo atual) | Godot 4.4 / godot-cpp |
|---|---|
| `#include "core/reference.h"` | `#include <godot_cpp/classes/ref_counted.hpp>` |
| `class NucleoHorda : public Reference` + `GDCLASS(NucleoHorda, Reference)` | `public RefCounted` + `GDCLASS(NucleoHorda, RefCounted)` |
| `#include "core/math/vector2.h"` | `#include <godot_cpp/variant/vector2.hpp>` |
| `#include "core/pool_vector.h"` | `#include <godot_cpp/variant/packed_float32_array.hpp>` e `packed_int32_array.hpp` |
| `PoolRealArray` | `PackedFloat32Array` (`real_t` é `float` nos dois engines, então a aritmética de `Vector2` continua float32) |
| `PoolIntArray` | `PackedInt32Array` |
| `PoolRealArray::Write w = r.write();` | `r.resize(n); float *w = r.ptrw();` (ou `r[i] = ...` direto) |
| `PoolIntArray::Write` | igual ao acima, com `ptrw()` |
| `const Array &p_d` | `const godot::Array &p_d` (ou `Array`; com `using namespace godot` nos includes) |
| `#include "core/class_db.h"` | `#include <godot_cpp/core/class_db.hpp>` |
| `ERR_FAIL_INDEX_V`, `ERR_FAIL_INDEX` | mesmos nomes em `<godot_cpp/core/error_macros.hpp>` (confirmar no código do branch 4.4) |
| `D_METHOD(...)` + `ClassDB::bind_method(...)` em `_bind_methods()` | mesma forma, com `godot::ClassDB` (confirmar com um exemplo do branch 4.4) |
| `static void _bind_methods();` | igual |
| `ClassDB::register_class<NucleoHorda>()` em `register_types.cpp` | ver entry point abaixo |
| `GDCLASS` | igual |

Entry point (substitui `register_horda_vita_types`): a função tem a assinatura do `example_library_init` do exemplo oficial, e dentro dela:

- `GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);`
- `init_obj.register_initializer(...)` e `init_obj.register_terminator(...)`
- `init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);`
- `return init_obj.init();`

No inicializador, o exemplo oficial usa `GDREGISTER_RUNTIME_CLASS(NucleoHorda);`, porque a classe só precisa existir em jogo (como o GDScript em runtime). Não encontrei documentação ligando `GDREGISTER_CLASS` a este caso; use a forma do exemplo.

Limite de argumentos: os métodos bindados têm no máximo 4 argumentos (`fixar`, `sf`, `n_mais_perto`), então o limite de binding não é problema.

Pontos a conferir no código real (não verifiquei fonte do branch 4.4 linha a linha): nomes exatos dos headers `godot_cpp/...`, e se `ERR_FAIL_INDEX_V` existe com esse nome no godot-cpp 4.4. Isso se resolve compilando.

Coisas que não precisam mudar: a lógica de `passo`, `gf/sf/gv/sv`, a grade (`std::vector`, `std::pair`), os enums e o `GDCLASS`. `Vector2` com `real_t` float é o mesmo tipo nos dois engines.

## 2. Build no Windows x86_64

- Ferramentas: Python 3 + `scons` (pip), Visual Studio 2022 Build Tools (MSVC) com C++. Recomendo MSVC: o export template oficial do Godot é MSVC, e misturar ABI é risco. MinGW funciona em tese, mas não é o caminho que eu testaria primeiro (não verifiquei fonte oficial sobre isso).
- Clonar `godotengine/godot-cpp` no branch `4.4`, com `gdextension/` e `src/` do próprio repo. Colocar o `nucleo_horda` em `src/` do projeto de extensão, mais um `register_types` com o entry point.
- Build: `scons platform=windows target=template_debug` e `scons platform=windows target=template_release`, ambos com `arch=x86_64`.
- Nome de saída (exemplo oficial): `libhorda.windows.template_debug.x86_64.dll` e `libhorda.windows.template_release.x86_64.dll`. O destino pode ser `bin/` dentro do projeto PC.
- O `SConstruct` do exemplo foi escrito para o master; no branch 4.4 o `SConstruct` que vem no repo do godot-cpp deve servir. Confirmar.

## 3. Como a DLL vai junto do jogo exportado

- `.gdextension` (fica em `res://`):

```
[configuration]
entry_symbol = "horda_init"
compatibility_minimum = "4.4"
reloadable = true

[libraries]
windows.debug.x86_64 = "res://bin/libhorda.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://bin/libhorda.windows.template_release.x86_64.dll"
```

- `compatibility_minimum = "4.4"` faz o Godot recusar a extensão em versões anteriores à 4.4. Na prática o projeto já usa 4.4.1, então fica coerente.
- `reloadable = true` só vale para builds de debug.
- Export: a documentação oficial diz que o `[libraries]` faz só o arquivo da plataforma ser exportado. O fórum da Godot (thread "Export GDExtension on Windows") mostra casos em que DLLs de dependência só foram copiadas quando declaradas em `[dependencies]`. **Não consegui confirmar pela documentação oficial se a DLL principal sai ao lado do `KIKIU.exe` ou só dentro do PCK.** Isso precisa de teste: exportar uma vez e conferir `build/`.
- O `embed_pck=true` do preset não mudou a regra. Se a DLL ficar fora do PCK, o `kikiu.iss` precisa copiá-la para a pasta de instalação.

## 4. Fallback quando a DLL falta

- A lógica do Godot: se a biblioteca não carregar, ela só gera erro no console e o jogo continua; `ClassDB.class_exists("NucleoHorda")` devolve `false`. O padrão planejado é:

```gdscript
var _nucleo = ClassDB.instantiate("NucleoHorda") if ClassDB.class_exists("NucleoHorda") else null
```

e, se for `null`, o `inimigos.gd` usa o caminho GDScript atual (`class V`, `atualizar`), sem tocar nele.
- Isso só fica seguro se o GDScript atual continuar sendo o caminho de referência e o C++ for um acelerador opcional. Duplicação de lógica é o custo.
- Não testado ainda: o comportamento exato de `class_exists` com extensão que falhou ao carregar em build exportado (esperado: `false`, mas precisa de prova no console).

## 5. Riscos

1. **Versão do engine.** A DLL precisa ser compilada contra o godot-cpp do mesmo minor (4.4). Com `compatibility_minimum = "4.4"`, uma extensão de 4.4 não carrega em 4.3. Trocar a versão do Godot no futuro exige recompilar.
2. **Antivírus / SmartScreen.** DLL nova sem assinatura digital pode ser marcada como suspeita, sobretudo as que o instalador copia para `%LOCALAPPDATA%`. O instalador já não é assinado, então o risco se soma. Assinatura de código custa dinheiro; **nada pago sem o Breno**.
3. **Plataformas.** Só existe preset Windows no PC. Linux e macOS não são entregues hoje, então basta `windows.*.x86_64`. Se entrar outra plataforma, cada uma precisa de build e de chave própria no `[libraries]`.
4. **Debug vs release.** Export de release precisa da `template_release`. Usar a DLL de debug num export de release é fonte comum de falha. Manter os dois nomes e conferir o build.
5. **Dependências de DLL.** O MSVC pode exigir o runtime (VCRUNTIME, UCRT) na máquina do jogador. Confirmar se o instalador já cobre isso ou se é preciso incluir.
6. **Ganho real no PC.** O ganho de 20-40x foi medido no Vita. No PC com GDScript pode ser desnecessário. Medir primeiro o custo de `inimigos.gd` no profiler do Godot, com muitos inimigos, antes de investir.

## 6. Plano em passos, com esforço estimado

1. Medição (0,5 dia): perfilar `inimigos.gd` no PC com a horda cheia. Se o custo não aparece, parar aqui.
2. Preparar ambiente (0,5 dia): godot-cpp branch 4.4, scons, MSVC. Compilar o exemplo oficial e carregar no projeto PC, só para provar o pipeline.
3. Portar `nucleo_horda` (0,5 a 1 dia): aplicar a tabela da seção 1, mais o entry point. Compilar debug e release.
4. Bridge GDScript com fallback (0,5 dia): `ClassDB.class_exists` + caminho GDScript preservado, com teste nos dois caminhos e comparação de saída com o mesmo seed.
5. Export e instalador (0,5 a 1 dia): exportar, conferir onde a DLL caiu, ajustar `kikiu.iss` se preciso, testar instalação silenciosa e jogo abrindo com o núcleo carregado e sem ele (renomear a DLL de propósito para testar o fallback).
6. Documentar no `LOGBOOK.md` e no `README.md` (seção de build), com a receita de compilar a DLL.

Total: cerca de 2 a 3 dias de trabalho focado. O passo 1 pode cancelar o restante.

## Recomendação

Viável tecnicamente, mas o ganho no PC não está provado. Faça o passo 1 antes de qualquer porte. Se o GDScript já aguenta a horda no PC, não vale o custo de manter DLL, CI de build e instalador. Se aguentar só no limite, o porte vale, com o fallback GDScript mantido.

## Fontes

- Godot 4.4 docs, "GDExtension C++ example": https://docs.godotengine.org/en/4.4/tutorials/scripting/gdextension/gdextension_cpp_example.html
- Godot 4.4 docs, "GDExtension docs system": https://docs.godotengine.org/en/4.4/tutorials/scripting/gdextension/gdextension_docs_system.html
- godot-cpp branch 4.4: https://github.com/godotengine/godot-cpp/tree/4.4
- Fórum Godot, "Export GDExtension on Windows": https://forum.godotengine.org/t/export-gdextension-on-windows/101734
- Fórum Godot, "How to automatically export .dll files?": https://forum.godotengine.org/t/how-to-automatically-export-dll-files/35315
- Godot 4.4 upgrade notes (migração 4.3 para 4.4): https://docs.godotengine.org/es/4.x/tutorials/migrating/upgrading_to_godot_4.4.html

Limites da pesquisa: a documentação oficial não diz se a DLL principal sai ao lado do exe no export; isso ficou como teste pendente. Nomes exatos de headers e macros do godot-cpp 4.4 foram tirados do conhecimento do exemplo oficial, sem leitura do código do branch; confirmar na compilação.
