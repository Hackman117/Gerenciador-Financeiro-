# FinaMind — Gerenciador Financeiro Pessoal

App de finanças pessoais feito em Flutter: lance receitas, despesas e transferências, acompanhe
orçamentos, metas e recorrências, controle cartões de crédito com parcelas e gere relatórios em PDF.
**Funciona 100% offline** — a sincronização em nuvem (Supabase) é opcional e só existe no build em
que você informar as credenciais.

- **Plataformas:** Android (principal), iOS, Web, Windows, macOS, Linux
- **Idioma da interface:** português (BR) — moeda `R$`, datas `dd/MM/yyyy`
- **Sem backend obrigatório:** todo o dado vive num SQLite local no dispositivo

---

## Índice

1. [Recursos](#recursos)
2. [Stack](#stack)
3. [Estrutura do projeto](#estrutura-do-projeto)
4. [Arquitetura e decisões](#arquitetura-e-decisões)
5. [Como rodar](#como-rodar)
6. [Banco de dados e migrações](#banco-de-dados-e-migrações)
7. [Sincronização com Supabase](#sincronização-com-supabase)
8. [Testes e análise estática](#testes-e-análise-estática)
9. [Suporte por plataforma](#suporte-por-plataforma)
10. [Roadmap](#roadmap)

---

## Recursos

Navegação em 10 abas (`NavigationRail` acima de 720px de largura, stack simples no celular):

| Aba | O que faz |
|---|---|
| **Início** | Hero de saldo total, receitas × despesas do mês, donuts por categoria, fluxo dos últimos 6 meses, série de tendência (semana/mês/ano/anos) e últimas movimentações. |
| **Transações** | Lista com busca, filtro por tipo e por período; entrada e edição em tela própria. |
| **Orçamentos** | Limite de gasto por categoria no mês, com navegação entre meses e barra de consumo. |
| **Metas** | Metas de aforro com aportes, resgates, prazo e progresso. Metas mensais de despesa, arrecadação e poupança. |
| **Relatórios** | Preview do relatório por período (semana, mês, 6 meses, 1 ano, tudo) e exportação em **PDF** com gráficos. |
| **Recorrentes** | Regras diária/semanal/mensal/anual com intervalo, geração dos vencidos, pausa e previsão de saldo. |
| **Contas** | Corrente, poupança, dinheiro, crédito, investimento, carteira e digital — com saldo inicial, saldo atual, conta padrão e arquivamento. |
| **Cartões** | Cartões com limite, dia de fechamento e de vencimento; consumo do limite, compras parceladas e fatura por parcela. |
| **Categorias** | Categorias de despesa e receita (15 já semeadas no primeiro uso) e subcategorias opcionais. |
| **Ajustes** | Tema (auto/claro/escuro), bloqueio por PIN, exportar CSV e PDF, login/sync e apagar todos os dados. |

Também: **lixeira** com soft delete e restauração, **trava por PIN** na abertura, telas de
autenticação (`/entrar`, `/conta`) e criação rápida por FAB (`/nova-transacao`).

## Stack

| Papel | Biblioteca |
|---|---|
| UI / SDK | Flutter 3.47 · Dart 3.13 (`sdk: ^3.13.5`) |
| Estado e injeção | `flutter_riverpod` 3 |
| Roteamento | `go_router` 18 (com redirect de autenticação) |
| Persistência | `drift` 2 + `drift_flutter` (SQLite) |
| Gráficos | `fl_chart` 1 |
| Nuvem e auth | `supabase_flutter` 2 |
| PDF | `pdf` + `printing` |
| Export CSV | `share_plus` + `path_provider` (as linhas são montadas na mão; `csv` está no pubspec mas não é importado em lugar nenhum) |
| Datas e moeda | `intl` (locale `pt_BR`) |
| Identificadores | `uuid` (id textual em todas as tabelas) |
| Geração de código | `build_runner` + `drift_dev` |
| Lints | `flutter_lints` 6 |

## Estrutura do projeto

```
lib/
  main.dart                 bootstrap: abre o banco, garante a conta padrão, sobe o ProviderScope
  app.dart                  MaterialApp.router + tema + PinLockGate + rotas
  core/
    theme/app_theme.dart    Material 3, claro e escuro, paleta e gradientes (AppColors)
    utils.dart              Formats (moeda/datas), CategoryIcons, AccountIcons
  data/
    database.dart           schema do drift + todo o DAO (queries, agregações, mutações)
    database.g.dart         código gerado pelo build_runner — não editar
    providers.dart          providers Riverpod (streams, FutureProviders, tema)
    auth_service.dart       contrato AuthService + implementação Supabase
    sync.dart               SupabaseService + SyncEngine (push/pull last-write-wins)
    report_service.dart     modelo ReportData + montagem do PDF
    credit_models.dart      CreditCard, Purchase, PurchaseParcel, CreditCardUsage
  features/                 uma pasta por aba, com a(s) tela(s) e seus sheets
  ui/
    common.dart             AppCard, EmptyState, MoneyField, showAppSheet, confirmDialog…
    charts.dart             donuts, barras de fluxo e linha de tendência
    report_render.dart      os mesmos gráficos desenhados para virar imagem no PDF
test/                       banco, contas, cartões/parcelas, auth e smoke de widget
android/ ios/ web/ linux/ macos/ windows/   runners nativos
```

## Arquitetura e decisões

**Dinheiro é sempre `int` em centavos.** `Formats.money(123456)` → `R$ 1.234,56`. Nenhuma coluna
monetária usa `double`, para a soma não acumular erro de arredondamento. A digitação passa por
`MoneyField`, que formata enquanto o usuário escreve (`1.234,56`) e devolve centavos em `centsOf`.

**Soft delete em tudo.** Toda tabela sincronizável tem `created_at`, `updated_at`, `deleted_at`.
Apagar marca `deleted_at`; a lixeira restaura (`deleted_at = NULL`) ou expurga de vez (`purgeRow`).
Isso mantém a linha recuperável **e** sincronizável — um delete precisa virar update na nuvem, senão
o outro dispositivo recria o registro.

**Camadas.** Tela → `ref.watch(provider)` → `AppDatabase` (DAO). Nenhum SQL solto dentro de widget,
e as agregações (saldo, gasto por categoria, série temporal) ficam no `database.dart` — com
`customSelect` quando o SQL resolve melhor que o Dart.

**Reatividade.** Streams do drift (`watchAccounts`, `watchTransactions`, `watchBudgets`…) alimentam
`StreamProvider`s, então as telas se atualizam sozinhas depois de qualquer escrita.

**Roteamento protegido.** O `routerProvider` reconstrói o `GoRouter` quando `authControllerProvider`
muda, para o `redirect` reavaliar `/conta` (exige sessão) e `/entrar` (bloqueia quem já entrou).

**Sessão espelhada localmente.** A tabela `users` guarda o perfil no SQLite; a sessão real vem do
Supabase. Sem rede o app continua funcionando com os dados locais.

## Como rodar

Pré-requisito: [Flutter](https://docs.flutter.dev/get-started/install) no channel `stable`
(`flutter --version` deve mostrar 3.47+ / Dart 3.13+).

```bash
flutter pub get

# gera lib/data/database.g.dart — obrigatório na primeira vez e depois de mexer no schema
dart run build_runner build --delete-conflicting-outputs

# rodar
flutter run -d windows     # desktop (requer Visual Studio com o workload de C++)
flutter run -d chrome      # web (veja o aviso de WASM em "Suporte por plataforma")
flutter run -d android     # aparelho ou emulador Android
```

Build de produção:

```bash
flutter build apk --release       # Android
flutter build windows --release   # Windows
flutter build web --release       # Web
```

### Configuração via `--dart-define`

Nenhuma chave fica no código — `AppConfig` lê do ambiente de compilação:

```bash
flutter run --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=sua-anon-key
```

Sem essas duas variáveis, `AppConfig.hasSupabase` é `false`: as telas de login e sync informam que a
nuvem está desativada e o app roda apenas com o SQLite local. Esse é o comportamento padrão do
repositório — clonar e rodar funciona sem configurar nada.

## Banco de dados e migrações

Schema em `lib/data/database.dart` (`schemaVersion = 3`):

| Tabela | Conteúdo |
|---|---|
| `accounts` | conta, tipo, ícone, cor, saldo inicial, `include_in_total`, `is_default`, `archived` |
| `categories` / `subcategories` | tipo despesa/receita, ícone, cor, `status` ativo/inativo |
| `transactions` | tipo (`income`/`expense`/`transfer`), valor em centavos, data, `recurring_id`, `credit_card_id`, `purchase_id`, `subcategoryId`, `status` |
| `recurring_rules` | frequência, intervalo, `start_date`, `next_due_date`, `auto_create`, `paused` |
| `budgets` | limite por categoria por mês (chave `YYYY-MM`) |
| `goals` / `goal_contributions` | metas de aforro e aportes |
| `settings` | chave/valor: `theme_mode`, `app_pin`, `last_sync_at`, `goal_expense`, `goal_income`, `goal_savings` |
| `credit_cards` / `purchases` / `purchase_parcels` | criadas com `CREATE TABLE IF NOT EXISTS` fora do drift, porque a feature entrou depois da versão 1 do schema |

`MigrationStrategy`: o `onCreate` cria tudo, semeia as 15 categorias padrão e garante a conta
"Carteira"; o `onUpgrade` adiciona colunas e tabelas conforme a versão de origem
(`_ensureCreditTables` roda nos dois casos por ser idempotente).

Para alterar o schema: incremente `schemaVersion`, trate o `onUpgrade` e rode `build_runner` de novo.

## Sincronização com Supabase

`SyncEngine.run()` (em `lib/data/sync.dart`) faz push → pull → push usando o timestamp de
`updated_at`, com resolução **last-write-wins**, e grava `last_sync_at` como marcador incremental —
a próxima rodada só troca o que mudou desde então.

Tabelas sincronizadas, na ordem de aplicação (respeitando as FKs):
`accounts`, `categories`, `transactions`, `recurring_rules`, `budgets`, `goals`,
`goal_contributions`.

Cada linha sobe com `user_id`, então o isolamento por usuário precisa existir no backend: crie as
tabelas no Supabase com **RLS** e políticas que liberam apenas `auth.uid() = user_id` em select,
insert e update. `credit_cards`, `purchases` e `purchase_parcels` ainda **não** participam do sync.

## Testes e análise estática

```bash
flutter test                    # unitários + widget
flutter test --coverage
flutter analyze                 # lints do flutter_lints
dart run build_runner build     # regenerar o código do drift
```

Cobertura em `test/`:

- **`database_test.dart`** — schema, seed, dinheiro em centavos, soft delete, unicidade da conta
  padrão e saldo considerando receitas, despesas e transferências.
- **`accounts_test.dart`** — CRUD de contas na UI, arquivar/reativar, exclusão em cascata.
- **`credit_cards_test.dart`** — cartões e compras: à vista e em 2/6/12 parcelas, divisão exata do
  valor, cancelamento devolvendo o limite, parcela paga reduzindo o consumo.
- **`auth_test.dart`** — login, cadastro e erros com um `FakeAuthService`, restauração de sessão e
  guards de rota (sem rede).
- **`widget_test.dart`** — smoke da árvore do app.

Os testes de banco usam `AppDatabase.forTesting` com executor em memória — nada toca o SQLite real.

## Suporte por plataforma

| Plataforma | Estado | Observação |
|---|---|---|
| Android | principal | `applicationId` e `namespace` = `com.finamind.finamind`; `minSdk` segue o padrão do Flutter |
| iOS / macOS | requer Xcode | não é possível compilar a partir do Windows |
| Windows desktop | funciona | exige o workload *Desktop development with C++* (MSVC, CMake, Windows SDK) no Visual Studio |
| Web | precisa de ajuste | `web/` ainda não contém `sqlite3.wasm` nem `drift_worker.js`; sem esses arquivos o drift não abre o SQLite no navegador. Gere as duas artes com `sqlite3_wasm_build` (ou copie em `web/`) antes de usar o alvo web. |

## Roadmap

- [ ] Levar `credit_cards`, `purchases` e `purchase_parcels` para o schema do drift e para o sync.
- [ ] Paginação real na tela de transações — hoje o stream tem teto de 500 linhas e a busca filtra em Dart.
- [ ] Colocar os artefatos WASM em `web/` para o build web funcionar.
- [ ] Reabrir a trava de PIN ao voltar para o app (hoje só bloqueia na abertura).
- [ ] Sugerir categoria a partir da descrição já usada (o DAO expõe `recentDescriptions`).

---

Feito com Flutter. Nenhum dado sai do dispositivo a menos que você configure e conecte o Supabase.
