# Mensagens Secretas (Flutter)

App simples e privado para trocar mensagens cifradas com AES-256, usando o
WhatsApp apenas como "cano de transporte" do texto já criptografado.

Fluxo: **digitar → cifrar localmente → abrir WhatsApp com o texto cifrado
pronto** e, do outro lado, **colar → decifrar localmente**. Tudo roda 100%
offline no aparelho — o WhatsApp só vê um texto em Base64 sem sentido.

---

## 1. Pré-requisitos

- Flutter SDK instalado (`flutter --version` deve funcionar). Se não tiver,
  siga https://docs.flutter.dev/get-started/install
- Um emulador Android/iOS configurado, ou um celular físico com depuração
  USB habilitada (o deep link do WhatsApp só funciona de verdade em um
  aparelho com o WhatsApp instalado — em emulador sem o app, ele cai no
  fallback de compartilhamento).

## 2. Como rodar

```bash
# Dentro da pasta secret_chat_app
flutter pub get
flutter run
```

Isso instala as dependências (`encrypt`, `crypto`, `url_launcher`,
`share_plus`, `shared_preferences`) e roda o app no dispositivo/emulador
conectado.

## 3. Configuração nativa necessária (importante!)

Para o Android 11+ e o iOS conseguirem checar/abrir o WhatsApp via deep
link, é preciso declarar essa "intenção" explicitamente. Sem isso,
`canLaunchUrl` pode sempre retornar `false` e o app vai direto para o
fallback de compartilhamento (o que também funciona, mas não é o fluxo
mais direto).

### Android — `android/app/src/main/AndroidManifest.xml`

Adicione o bloco `<queries>` dentro da tag `<manifest>` (fora da tag
`<application>`):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <queries>
        <package android:name="com.whatsapp" />
    </queries>

    <application ...>
        ...
    </application>
</manifest>
```

### iOS — `ios/Runner/Info.plist`

Adicione dentro do `<dict>` principal:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>whatsapp</string>
</array>
```

Sem esse passo, no iOS o `canLaunchUrl('whatsapp://...')` sempre retorna
`false` e o app usa automaticamente o menu de compartilhamento nativo
(que também funciona bem, só é um clique a mais).

## 4. Como usar

1. Nos dois celulares (o seu e o do seu filho), instale o app e definam
   **a mesma Chave Secreta** no campo do topo (ex: uma frase que só vocês
   sabem).
2. Aba **Enviar**: digite a mensagem normal → toque em
   "Criptografar e Enviar" → o WhatsApp abre com o texto cifrado pronto,
   só escolher o contato e mandar.
3. Aba **Receber**: cole o texto cifrado que chegou pelo WhatsApp → toque
   em "Descriptografar" → a mensagem original aparece na tela (com opção
   de copiar).

## 5. Notas técnicas e limitações

- **Criptografia**: AES-256 em modo CBC. A chave de 256 bits é derivada da
  senha digitada via SHA-256. Um IV (vetor de inicialização) aleatório de
  16 bytes é gerado a cada mensagem e vai junto do pacote cifrado (antes
  do Base64), então o destinatário consegue extrair o IV certo para
  decifrar.
- **A senha nunca sai do aparelho**: ela é usada só localmente para gerar
  a chave de criptografia e fica salva apenas no `SharedPreferences` do
  próprio celular (armazenamento local, não sincronizado com nuvem).
- **Segurança da senha em si**: SHA-256 puro não tem "custo computacional"
  proposital (diferente de PBKDF2/Argon2), então uma senha muito curta ou
  óbvia ainda seria fraca contra alguém que conseguisse o texto cifrado e
  tentasse adivinhar a senha por força bruta. Para o uso combinado entre
  pai e filho, uma frase-senha longa e não óbvia (ex: "girafa-azul-quinta-
  feira-42") já é suficiente na prática.
- **Modo CBC vs GCM**: optei por CBC por ser o mais simples de implementar
  corretamente com o pacote `encrypt`. Se quiser autenticação integrada
  (detectar se o texto cifrado foi alterado), dá para migrar para AES-GCM
  depois — me avise se quiser essa versão.
