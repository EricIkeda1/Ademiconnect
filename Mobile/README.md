# Tutorial completo: Ademiconnect (Flutter + GitHub)

Este arquivo reúne o passo a passo para instalar, rodar o app Flutter localmente e usar o projeto como seu repositório no GitHub.

---

## 1. Pré‑requisitos

- Flutter 3.x instalado e configurado no PATH.
- Git instalado.  
- VS Code (ou outro editor) instalado.  
- Emulador Android/iOS ou navegador (para rodar como web).
- Conta no GitHub configurada com usuário e e‑mail.  
- **Arquivo `.env` na pasta raiz do projeto mobile (obrigatório). Sem esse arquivo, o app não conseguirá acessar Supabase nem carregar dados.**  

---

## 2. Clonar o repositório na pasta do projeto

Escolha uma pasta onde você guarda seus projetos, por exemplo:

- `C:\Projetos\Mobile`  

No terminal, execute na ordem:

1. `cd C:\Projetos\Mobile`  
2. `git clone https://github.com/EricIkeda1/Ademiconnect.git`  
3. `cd Ademiconnect`  

Depois de clonar, a pasta deve conter arquivos como `pubspec.yaml`, `lib`, `android`, `ios` etc. 

---

## 3. Arquivo `.env` na raiz do Mobile

> Importante: **sem o arquivo `.env` na pasta raiz do projeto mobile, o app abre mas não consegue acessar nada (sem autenticação, sem listar dados, sem sincronizar).**

O arquivo `.env` contém as configurações sensíveis necessárias para o app se conectar ao Supabase (URL, chaves, etc.).  
Esse arquivo **não é público** e **será fornecido somente se solicitado e/ou devidamente autorizado**.

Coloque o arquivo `.env` fornecido diretamente na raiz do projeto Flutter (mesmo nível do `pubspec.yaml`).  
Certifique‑se de que ele está exatamente na raiz do app mobile, e não em subpastas.

---

## 4. Abrir o projeto no VS Code

1. Abra o VS Code.  
2. Menu: `File -> Open Folder`.  
3. Selecione a pasta do projeto, por exemplo:  
   `C:\Projetos\Mobile\Ademiconnect`  
4. Aguarde o VS Code reconhecer o projeto Flutter. 

---

## 5. Instalar dependências do Flutter

No terminal integrado do VS Code (Ctrl + `), execute, um por vez:

1. `flutter clean`  (opcional, recomendado na primeira vez)  
2. `flutter pub get`  
3. `flutter doctor`  

Verifique se o `flutter doctor` não mostra erros críticos.

---

## 6. Rodar o app Flutter localmente

Na pasta do projeto (`C:\Projetos\Mobile\Ademiconnect`), com um dispositivo ou emulador aberto (ou Chrome):

- Para rodar normalmente:  
  `flutter run`  

- Para logs detalhados em caso de erro:  
  `flutter run --verbose`  

Se o `.env` não estiver presente na raiz ou estiver com chaves erradas, o app abre mas não consegue logar ou carregar dados do Supabase.

---

## 7. Resumo da configuração do Supabase

- O app lê as credenciais do Supabase a partir do `.env` na raiz do mobile.  
- Sem esse `.env`, o app não consegue autenticar nem buscar dados do backend.  
- Garanta que o `.env` tenha, no mínimo:  
  - `SUPABASE_URL`  
  - `SUPABASE_ANON_KEY`  
- Use as credenciais do projeto Supabase correto.

---

## 8. Gerar APK Android com [flutter build apk]

Depois que o app estiver funcionando em modo de desenvolvimento, é possível gerar um arquivo APK para instalar em celulares Android.

1. Na raiz do projeto (`C:\Projetos\Mobile\Ademiconnect`), execute no terminal:  
   - `flutter build apk`  

2. Esse comando gera um build em modo release (otimizado) e cria o arquivo APK na pasta:  
   - `build/app/outputs/flutter-apk/app-release.apk` ou similar. 
