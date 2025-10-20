# JornadaAppAdemicom - Flutter + Supabase (Offline‑First)

Aplicativo móvel Flutter para gestão de Leads/Clientes e visitas com fluxo P.A.P., integração ao CRM Ademicon, cache local persistente e sincronização automática quando a internet volta. Desenvolvido em Londrina-PR para otimizar a produtividade de consultores em campo.

## Descrição

O **JornadaAppAdemicom** é uma solução completa de gestão de clientes e visitas que funciona offline-first. O app permite:

- **Cadastro de clientes** com validações completas (nome, telefone, endereço, data de visita)
- **Cache local em JSON** (SharedPreferences) para trabalhar sem internet
- **Sincronização automática** ao reconectar (connectivity_plus 6.x)
- **Autenticação e banco Supabase** com políticas RLS por usuário
- **Governança por perfis**: Gestor e Consultor
- **Ciclo de vida do Lead**: prazo de 3 meses, transferências auditadas
- **Importação via Excel** para CRM (até 6 colunas por arquivo)
- **Home com KPIs**: total de clientes, visitas hoje, alertas, finalizados
- **Rua de Trabalho - Hoje**: card com a próxima visita agendada

## Recursos principais

- ✅ Autenticação e RLS no Supabase (Row Level Security por `auth.uid()`)
- ✅ Upsert com `onConflict: 'id'` + `.select()` para confirmação imediata
- ✅ Fila offline: operações são enfileiradas e enviadas automaticamente
- ✅ Verificação de "internet real" (DNS lookup) antes de sincronizar
- ✅ Evento broadcast `onSynced`: atualiza Home automaticamente após sync
- ✅ Máscaras de input (telefone, CEP) e validações de formulário
- ✅ Notificações de Lead próximo de caducar (penúltima semana)
- ✅ Auditoria de transferências de Lead entre consultores

## 🛠️ Stack técnica

- **Flutter** 3.x / **Dart** 3.x
- **Supabase** (Auth + Postgres + RLS)
- **Pacotes principais**:
  - `supabase_flutter` — integração Supabase
  - `connectivity_plus` ≥ 6.x — detecta reconexão (List<ConnectivityResult>)
  - `shared_preferences` — cache e fila offline
  - `intl` — formatação de datas
  - `mask_text_input_formatter` — máscaras de telefone/CEP
  - `uuid` — geração de IDs únicos
    
## 🔄 Como funciona o Offline‑First

### 1. Salvar cliente

- Atualiza **cache local** imediatamente (JSON em SharedPreferences)
- Tenta **upsert no Supabase**: `onConflict: 'id'` + `.select()`
  - ✅ **Sucesso**: retorna `true`, emite evento `onSynced`, UI atualiza (snackbar verde)
  - ❌ **Falha** (sem rede/RLS): enfileira em `pending_ops`, retorna `false` (snackbar amarelo)

### 2. Reconectar à internet

- **Listener** detecta transição offline→online (connectivity_plus 6.x)
- Faz **debounce** de 700ms para estabilizar
- Verifica **"internet real"** via DNS lookup (`1.1.1.1`)
- Exige **sessão ativa** (RLS do Supabase)
- **Drena a fila**: faz upsert/delete de cada item
- Ao esvaziar a fila, **emite evento** `onSynced` → Home atualiza automaticamente

### 3. Inicialização do app

- Se houver internet real + sessão válida, tenta drenar a fila no startup

## 📊 Regras de importação (Excel para CRM)

- **Até 6 colunas** por arquivo; ordem não importa, apenas os títulos
- **Títulos aceitos** (exatos): `nome`, `codigo_pais`, `celular`, `data_nascimento`, `email`, `classificacao`, `obs`

### Validações por coluna

| Coluna | Obrigatório | Formato/Regras | Max |
|--------|-------------|----------------|-----|
| `nome` | ✅ | Não pode estar na Blacklist LGPD | 100 |
| `codigo_pais` | ❌ | Número sem "+" (ex.: 55, 1, 201) | - |
| `celular` | ✅ | 10-11 dígitos; único no sistema | - |
| `data_nascimento` | ❌ | AAAA-MM-DD (ex.: 1993-05-21) | - |
| `email` | ❌ | Email válido | 100 |
| `classificacao` | ❌ | Múltiplas separadas por ";" | 90 |
| `obs` | ❌ | Texto livre | 1000 |
