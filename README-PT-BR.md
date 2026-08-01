# PSBBN Definitive Project

| **[English](https://github.com/CosmicScale/PSBBN-Definitive-Project/blob/main/README.md)** | **Português (Brasil)** |

[![Licença: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/blob/main/LICENSE)  
Este é o Projeto Definitivo para o software "PlayStation Broadband Navigator" da Sony (também conhecido como BB Navigator ou PSBBN) para o console de videogame "PlayStation 2" (PS2).

O PSBBN é um software oficial da Sony para o PlayStation 2, lançado exclusivamente no Japão. Introduzido em 2002 como um substituto para o OSD do PS2, ele exigia tanto um disco rígido quanto um adaptador de rede para funcionar. Ele adicionou muitos recursos novos:
- Inicialização de jogos a partir do disco rígido
- Acesso a canais online
- Download de jogos completos, demonstrações, vídeos e imagens
- Extração de CDs de áudio e transferência de música para gravadores MiniDisc no Canal de Música
- Assistir a vídeos no Canal de Filmes
- Transferência de fotos de uma câmera digital e visualização delas no Canal de Fotos

O **PSBBN Definitive Project** (anteriormente PSBBN Definitive English Patch) começou em 2023 como um patch de idioma Inglês para o PSBBN, mas expandiu-se continuamente bem além de seu escopo original. Este projeto agora visa fornecer a configuração definitiva para a unidade interna do PlayStation 2.

Você pode saber mais sobre o software PSBBN original na [Wikipedia](https://en.wikipedia.org/wiki/PlayStation_Broadband_Navigator) e acompanhar o desenvolvimento deste projeto no meu [canal do YouTube](https://www.youtube.com/@CosmicScaleFactor).

# Doações  
Se você aprecia o meu trabalho e quer apoiar o desenvolvimento contínuo do **PSBBN Definitive Project** e de outros projetos relacionados ao PS2, [você pode doar no meu Ko-Fi](https://ko-fi.com/cosmicscale).

Este projeto usa o [webhook.site](https://webhook.site/) para contribuir e relatar automaticamente artes e ícones ausentes para o [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database) e para o [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database). À medida que o projeto cresceu em popularidade, estamos excedendo o limite oferecido por uma conta gratuita. Uma assinatura paga custa $9/mês ou $90/ano, e as doações também ajudam a financiar isso.

# Demonstração em vídeo do PSBBN

[![PSBBN em 2024](https://github.com/user-attachments/assets/298c8c0b-5726-4485-840d-9d567498fd95)](https://www.youtube.com/watch?v=kR1MVcAkW5M)

# Recursos
Existem duas opções de instalação:
- [PSBBN e HOSDMenu](#instalar-psbbn-e-hosdmenu) — requer um Adaptador de Rede oficial da Sony[*](#known-issues)
- Apenas o [HOSDMenu](#instalar-apenas-o-hosdmenu) — suporta tanto os Adaptadores de Rede oficiais da Sony quanto os adaptadores de HDD de terceiros

Ambas as opções de instalação oferecem:
- [Instaladores](#instalar-psbbn-e-hosdmenu) que facilitam a configuração
- Suporte para unidades maiores com o [APA-Jail](#apa-jail) — um esquema de particionamento híbrido permite que um sistema de arquivos exFAT e o PlayStation File System (PFS) coexistam na mesma unidade
- Sistema de arquivos exFAT usado para armazenamento e gerenciamento fácil de jogos e aplicativos homebrew
- Sistema de arquivos PFS usado para o software de sistema e suporte a legado
- [HOSDMenu](#hosdmenu) — uma versão modificada do software HDD-OSD da Sony que oferece muitas vantagens sobre o FreeHDBoot
- Visualizar, navegar e iniciar os jogos e aplicativos diretamente da [Rotina de pesquisa](#hosdmenu), representados por [ícones 3D](https://github.com/CosmicScale/HDD-OSD-Icon-Database)
- Suporte a [ID do Jogo](#id-do-jogo) para o **Pixel FX Retro GEM**, **MemCard Pro** e **SD2PSX** — funciona com jogos e aplicativos instalados, bem como discos de jogos físicos
- Suporte ao [MechaPwn](#executar-discos-de-jogos-de-ps1-e-ps2) com correção automática do logotipo do PS2, permitindo que jogos importados e discos de backup sejam iniciados. Também ajusta o modo de vídeo do driver do PlayStation para discos de jogos de PS1 importados
- Inclui os aplicativos [wLaunchELF-R3Z](#wlaunchelf-r3z), [R3CONFIGURATOR](#r3configurator) e [POPSLoader](#popsloader), com a escolha do [OPL](#open-ps2-loader-opl) ou [NHDDL](#nhddl) para o iniciador de jogos
- Um [Instalador de Jogos e Aplicativos](#instalar-jogos-e-aplicativos) que automatiza totalmente a instalação de jogos de PS1 e PS2, bem como de aplicativos homebrew:
  - Cria recursos e baixa artes e ícones para todos os jogos e aplicativos
  - Oferece uma opção para criar [Memory Cards Virtuais](#memory-cards-virtuais) (VMCs) para jogos de PS2, com suporte para [Grupos VMC](#memory-cards-virtuais) tanto para jogos de PS1 (*MGS*, etc.) quanto de PS2 (*Gran Turismo*, etc.)
  - Configura jogos de PS1 com vários discos para permitir a troca de discos
  - Instala automaticamente as [correções do HugoPocked POPStarter](#popstarter)
  - Converte arquivos `.bin`/`.cue` para `.VCD` (PS1) ou `.ISO` (PS2)
  - Configura as definições de compatibilidade do OPL para os jogos
  - Adiciona os aplicativos instalados ao menu de sistema do [HOSDMenu](#hosdmenu)

**Exclusivo para instalações com o PSBBN:**
- **PSBBN Definitive Patch** — uma versão aprimorada do software [PSBBN](#psbbn) da Sony que oferece [muitas vantagens](#psbbn) em relação à versão padrão
- Visualizar, navegar e iniciar os jogos e aplicativos diretamente da [Coleção de Jogos](#coleção-de-jogos) com uma interface no estilo 'cover-flow'
- [Canal de Música](#canal-de-música) para reprodução de música e extração de CDs. Use o [Instalador de Música](#instalar-música) para instalar arquivos de música a partir do PC (`.mp3`, `.m4a`, `.flac`, `.ogg`)
- [Canal de Filmes](#canal-de-filmes) para reprodução de vídeo. Baixe vídeos dos [canais online](#canal-de-internet) ou use o [Instalador de Filmes](#instalar-filmes) para instalar arquivos de vídeo a partir do PC (`.mp4`, `.m4v`, `.mkv`, `.vob`, `.pss`, `.psm` e outros formatos populares)
- [Canal de Fotos](#canal-de-fotos) para visualização de imagens. Importe imagens de unidades USB ou câmeras digitais, ou instale-as a partir do PC usando o [Instalador de Fotos](#instalar-fotos) (`.jpg`, `.png`, `.tif`, `.gif`, `.bmp` e outros formatos comuns)
- [Canal de Internet](#canal-de-internet) que oferece acesso a espelhos (mirrors) dos canais de jogos online originais de várias produtoras, permitindo que você baixe trailers de jogos, capturas de tela e jogue jogos retrô clássicos
- [Extras opcionais](#extras-opcionais), como a instalação do [PS2 Linux](#install-ps2-linux)

# Registro de Alterações

**29 de julho de 2026 - Seletor de Jogos v2, OSDMenu 1.3.0 e muito mais!**
<p></p>

[![Seletor de Jogos v2, OSDMenu 1.3.0 e muito mais!](https://github.com/user-attachments/assets/4395d7ec-7af4-4954-8e30-7b562c5cef3d)](https://youtu.be/UEsqDorgbew)

**[Seletor de jogos:](#saindo-dos-jogos)**
- Gerencie todos os seus jogos e aplicativos com o Seletor de jogos v2.
- Escolha quais títulos aparecem na Coleção de Jogos e na Rotina de pesquisa.
- Personalize a ordem em que as categorias são exibidas, como Jogos de PS2, Jogos de PS1, Inicializadores e Aplicativos, para ter controle total sobre a organização da sua biblioteca.

**OSDMenu:**
- [OSDMenu MBR](#osdmenu-mbr) e [HOSDMenu](#hosdmenu) atualizados para a versão [v1.3.0](#https://github.com/pcm720/OSDMenu/releases/tag/v1.3.0).
- Melhorados os tempos de inicialização do [PSBBN](#psbbn) e do [HOSDMenu](#hosdmenu).
- Adicionado suporte para [botões adicionais de inicialização pelo controle](#opções-de-inicialização). Agora todas as teclas são suportadas, exceto L3 e R3.
- [R3CONFIGURATOR](#r3configurator) atualizado para a versão [v1.3.0](https://github.com/saildot4k/R3CONFIGURATOR/releases/tag/v1.3.0).

Outras alterações:
- [POPSLoader](#popsloader) atualizado para a versão contínua mais recente.
- Instalação mais fácil dos [drivers ATA BDM Assault](#instalando-o-ata-bdm-assault) com o [POPSLoader](#popsloader).
- [wLaunchELF_R3Z](#wlaunchelf-r3z) atualizado para a v4.75.
- A configuração de idioma do [wLaunchELF_R3Z](#wlaunchelf-r3z) e do [POPSLoader](#popsloader) agora é definida automaticamente.
- O idioma e a [configuração dos botões](#reatribuir-botões-cruz-e-círculo) para o [wLaunchELF_R3Z](#wlaunchelf-r3z) agora são definidos automaticamente
- Adicionada uma tradução em português do Brasil do README do PSBBN Definitive Project.
- Diversas correções de bugs e limpeza de código.

<details>
<summary><b>02 de julho de 2026 - Localização Aprimorada, Seletor de Jogos, PS1 em exFAT, POPSLoader, wLaunchELF-R3Z e R3CONFIGURATOR</summary></b>
<p></p>

[![Localização Aprimorada, Seletor de Jogos, PS1 em exFAT, POPSLoader e Mais!](https://github.com/user-attachments/assets/c1828dbf-e1ba-4c67-8ae0-ccff79f4a524)](https://youtu.be/Bqf8XCfa0QM)  

**Novos Recursos:**
- Um registro de alterações agora é exibido antes do [Menu Principal](#menu-principal) sempre que uma nova atualização é lançada.
- Os scripts do **PSBBN Definitive Project** foram totalmente localizados para Inglês, Japonês, Francês, Espanhol, Alemão, Italiano e Português do Brasil. O idioma do sistema operacional é detectado automaticamente, e o projeto é executado nesse idioma, assumindo o Inglês como padrão caso não esteja disponível. Usuários de **Windows** precisarão atualizar para a versão mais recente do **[PSBBN Launcher for Windows](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/releases/download/latest/PSBBN-Launcher-For-Windows.ps1)** para que este recurso funcione.
- O [Instalador de Jogos](#instalar-jogos-e-aplicativos) agora conta com um [Seletor de Jogos](#seletor-de-jogos), permitindo selecionar quais jogos exibir na [Coleção de Jogos](#coleção-de-jogos) e na [Rotina de pesquisa](#hosdmenu). Se você tiver uma coleção grande, limitar o número de jogos exibidos pode melhorar sua experiência de navegação.
- Os jogos de PS1 agora são instalados na partição exFAT junto com os jogos e aplicativos de PS2, removendo as limitações de espaço causadas pelo APA. Jogos instalados anteriormente permanecerão na partição `POPS` e ainda estarão funcionais. Para jogar jogos de PS1 a partir da partição exFAT, você **DEVE** instalar os [drivers do ATA BDM Assault](#installing-ata-bdm-assault) em um Memory Card de PS2.
- Jogos de PS1 armazenados em um [compartilhamento de rede SMB](#iniciando-jogos-de-ps1-via-smb) agora podem ser iniciados a partir da [Coleção de Jogos](#coleção-de-jogos) e da [Rotina de pesquisa](#hosdmenu). Coloque um arquivo `POPSTARTER.ELF` renomeado com o prefixo `SB.` na pasta `POPS` e, em seguida, execute o [Instalador de Jogos](#instalar-jogos-e-aplicativos).
- O aplicativo [POPSLoader](#popsloader) foi adicionado. Isso permite que você navegue e carregue facilmente jogos de PS1. O [POPSLoader](#popsloader) pode ser iniciado a partir da [Coleção de Jogos](#coleção-de-jogos) ou do Menu Navigator, no navegador ou menu de sistema do [HOSDMenu](#hosdmenu), ou segurando o botão [△](#opções-de-inicialização) na inicialização.
- A integração com o [POPSLoader](#popsloader) foi adicionada ao [Instalador de Jogos](#instalar-jogos-e-aplicativos); a arte do jogo é baixada automaticamente para todos os jogos de PS1.
- O **wLaunchELF-ISR** foi substituído pelo [wLaunchELF-R3Z](#wlaunchelf-r3z), adicionando suporte para o gerenciamento de arquivos na partição exFAT da unidade interna. Ele agora pode ser iniciado na inicialização segurando o botão [START](#opções-de-inicialização).
- O **OSDMenu Configurator** foi substituído pelo [R3CONFIGURATOR](#r3configurator), adicionando suporte multilíngue.

**Aprimoramentos:**
- [Instalador do PSBBN e HOSDMenu](#instalar-psbbn-e-hosdmenu) e [Instalador apenas do HOSDMenu](#instalar-apenas-o-hosdmenu):
  - Não cria mais uma partição `POPS`, permitindo partições de Música e Conteúdos maiores ou uma partição exFAT maior.
  - A seleção de idioma foi removida. Agora ele é instalado automaticamente no mesmo idioma do sistema operacional, assumindo o Inglês como padrão caso esse idioma não esteja disponível.
- [Instalador apenas do HOSDMenu](#instalar-apenas-o-hosdmenu):
  - Permite reservar espaço para futuras partições APA. Até 50% da capacidade da unidade (máximo de 2 TB) pode ser reservado.
- [Instalador de Jogos](#instalar-jogos-e-aplicativos):
  - O idioma e a configuração dos botões agora são definidos automaticamente no [OPL](#open-ps2-loader-opl) e no [R3CONFIGURATOR](#r3configurator) para corresponderem às configurações de instalação.
  - Os jogos de PS2 agora são exibidos primeiro na [Coleção de Jogos](#coleção-de-jogos) e na [Rotina de pesquisa](#hosdmenu), seguidos pelos jogos de PS1 e aplicativos homebrew.
  - O feedback visual do [Instalador de Jogos](#instalar-jogos-e-aplicativos) foi simplificado e agora inclui barras de progresso.
  - Agora você tem a opção de desativar as [VMCs de PS2](#memory-cards-virtuais) caso elas tenham sido ativadas anteriormente.
  - O espaço disponível agora é exibido em MB, GB ou TB, dependendo do tamanho.
  - As artes do OPL agora são salvas diretamente na unidade do PS2.
  - Instruções foram adicionadas para usuários de **Linux** sobre onde colocar os arquivos suportados, espelhando o funcionamento do [PSBBN Launcher for Windows](#instalando-no-windows).
- Todos os arquivos de log agora são truncados quando excedem 4 MB.
- O número do commit atual do **PSBBN Definitive Project** é registrado nos arquivos de log.
- Um link para o [guia de solução de problemas](#solucao-de-problemas) foi adicionado a todas as mensagens de erro.
- O arquivo **readme** foi atualizado, reestruturado e aprimorado.

**Correções de Bugs:**
- O script agora é impedido de ser executado em modo não interativo.
- O [OPL](#open-ps2-loader-opl) foi atualizado para a versão v1.2.0-Beta-2245-3e3f34e, corrigindo um problema de leitura de configuração na inicialização que alguns usuários estavam enfrentando.
- O [Instalador de Música](#instalar-música) agora suporta a manipulação de caracteres internacionais.
- O [Instalador de Jogos](#instalar-jogos-e-aplicativos) agora ignora arquivos ocultos, impedindo que sejam instalados.
- Arquivos `.ZSO` duplicados são impedidos de serem descompactados quando arquivos `.ZSO` estão presentes e o [NHDDL](#nhddl) está selecionado como o iniciador de jogos.
- Exibe um aviso se um arquivo `.bin` estiver ausente ao converter para `.iso`. Ignora a conversão de `.VCD` se o arquivo `.bin` estiver ausente.
- Verificações aprimoradas para a criação bem-sucedida das listas de jogos.
- Lida corretamente com IDs de jogos duplicados, mesmo quando os arquivos estão em pastas diferentes.
- Corrigido o truncamento incorreto de títulos de jogos japoneses na [Rotina de pesquisa](#hosdmenu).
- A montagem de `__linux.9` agora é ignorada para instalações não Japonesas, permitindo o suporte a unidades menores.
</details>

<details>
<summary><b>16 de abril de 2026 - Compatibilidade de PS1 Aprimorada, VMCs de PS2, Atualização do OPL e Mais!</summary></b> 
<p></p>

[![Compatibilidade Aprimorada de PS1, VMCs de PS2, Atualização do OPL e Mais!](https://github.com/user-attachments/assets/1dc75789-bbd4-45df-9615-7e9bd8bd3ac5)](https://youtu.be/oRm3QIwdf1o)  

- O **[OPL](#open-ps2-loader-opl)** foi atualizado para a versão **v1.2.0 Beta-2241-39afed2** — corrige problemas de leitura de configuração na partição exFAT da unidade interna
- O **[NHDDL](#nhddl)** foi atualizado para a versão **[v1.2.2](https://github.com/pcm720/nhddl/releases/tag/v1.2.2)**
- O **[Neutrino](#nhddl)** foi atualizado para a versão **[v1.8.0](https://github.com/rickgaiser/neutrino/releases/tag/v1.8.0)** — reduz o tempo de inicialização dos jogos em cerca de 4 segundos
- O **[OSDMenu](#osdmenu-mbr)** foi atualizado para a versão **v1.2.1** — corrige problemas com argumentos de inicialização ao iniciar arquivos ELF via botão do controle na inicialização

**[Instalador de Jogos](#instalar-jogos-e-aplicativos):**
- Atribui o iniciador de jogos escolhido ([OPL](#open-ps2-loader-opl) ou [NHDDL](#nhddl)) ao botão □, permitindo que ele seja iniciado rapidamente na inicialização do console
- Cria um arquivo de configuração do **[OPL](#open-ps2-loader-opl)** na unidade. O BDM HDD, Aplicativos e artes agora são ativados automaticamente
- Jogos no formato `ZSO` agora têm o "Modo de Compatibilidade 1" ativado automaticamente em suas configurações individuais do **[OPL](#open-ps2-loader-opl)**
- Múltiplos jogos que compartilham o mesmo Title ID agora podem ser instalados, permitindo a instalação de uma variedade de modificações (mods)
- Jogos de PS1 agora apresentam uma nova borda no estilo PSN na **[Coleção de Jogos](#coleção-de-jogos)** do PSBBN, tornando mais fácil distinguir entre jogos de PS1 e PS2
- Instalação automática das **[correções do HugoPocked POPStarter](https://www.psx-place.com/threads/hugopocked-fixes-for-popstarter.39750/)**, melhorando a compatibilidade com mais de 100 jogos de PS1

**Correções de Bugs:**
- O **OSDMenu Configurator** agora possui a arte correta na aba de Apps dentro do **[OPL](#open-ps2-loader-opl)**
- Corrigida a renomeação de `.vcd` para `.VCD` em sistemas de arquivos que não diferenciam maiúsculas de minúsculas
- Exclui a pasta `neutrino` existente antes de atualizar para evitar conflitos
- Garante que os arquivos de configuração do OSDMenu terminem com uma nova linha antes de anexar conteúdo

**README**:
- Nova seção: [Opções de Inicialização](#opções-de-inicialização)
- Adicionada tabela para as [teclas de atalho do POPStarter](#popstarter)
- Adicionado o Debian à lista de [sistemas operacionais recomendados](#instalando-no-linux)
- Adicionados novos recursos à seção [Instalar Jogos e Aplicativos](#instalar-jogos-e-aplicativos) section
- Alteradas as referências de Neutrino para [NHDDL](#nhddl), refletindo como os jogos agora são iniciados
- Melhorias gerais

**27 de março de 2026 - Memory Cards Virtuais (VMCs) para jogos de PS2**
- O **[Instalador de Jogos e Aplicativos](#instalador-de-jogos-e-aplicativos)** agora ofereça a opção de ativar **[VMCs](#memory-cards-virtuais)** para jogos de PS2. Nenhuma configuração adicional é necessária
- Este recurso é compatível tanto com o **[OPL](#open-ps2-loader-opl)** quanto com o **[NHDDL](#nhddl)**
- Suporta **[Grupos VMC](#memory-cards-virtuais)**

**26 de março de 2026 - Atualização 4.2.0: Novos Canais Online e Localização em Francês**
- Software de sistema do PSBBN atualizado para o patch 4.2.0
- O Canal de Jogos foi renomeado para **[Canal de Internet](#canal-de-internet)**, refletindo o seu foco online
- Novos canais online adicionados: CANAL BANDAI, So-Net e BIGLOBE
- Baixe novos trailers de jogos em maior qualidade, com imagens de miniatura
- O suporte ao idioma Francês agora está disponível para o PSBBN
</details>

<details>
<summary><b>05 de março de 2026 - Instaladores de Filmes e Fotos, OSDMenu Configurator e Mais!</summary></b> 
<p></p>

[![Instaladores de Filmes, Fotos, OSDMenu Configurator e Mais!](https://github.com/user-attachments/assets/f0fae1ee-bf04-4aea-88a6-89e030926282)](https://youtu.be/_jKzzsClgOY)

**Mais Idiomas:**
- Além do Inglês, Japonês e Alemão, o PSBBN agora está disponível em Italiano, Português do Brasil e Espanhol

**[Atualizar Software de Sistema do PS2:](#atualizar-software-do-sistema-do-ps2)**
- Substitui a opção **Update PSBBN Software**. Esta nova opção atualiza o software de sistema tanto do **[PSBBN](#psbbn)** quanto do **[OSDMenu](#hosdmenu)**
- O **[Menu Principal](#menu-principal)** do **PSBBN Definitive Project** agora exibe uma notificação quando **atualizações do software de sistema do PS2** estão disponíveis

**[Instalar Filmes:](#instalar-filmes)**
- A opção **[Instalar Filmes](#instalar-filmes)** foi adicionada ao menu **[Menu de Instalação de Mídia](#instalar-mídia)**
- Agora você pode colocar uma variedade de formatos de vídeo na pasta `movie`, incluindo `MP4`, `M4V`, `MKV`, `VOB` e outros
- Selecionar **[Instalar Filmes](#instalar-filmes)** converterá os arquivos de vídeo para o formato `PSM` suportado pelo **[PSBBN](#psbbn)**
- Os vídeos poderão então ser reproduzidos no **[Canal de Filmes](#canal-de-filmes)** do PSBBN

**[Instalar Fotos:](#instalar-fotos)**
- A opção **[Instalar Fotos](#instalar-fotos)** foi adicionada ao menu **[Menu de Instalação de Mídia](#instalar-mídia)**
- Agora você pode colocar uma variedade de formatos de imagem na pasta `photo`, incluindo `JPG`, `PNG`, `TIF`, `GIF`, `BMP` e outros
- Selecionar **[Instalar Fotos](#instalar-fotos)** converterá os arquivos de imagem para `PNG` e os redimensionará, se necessário
- As imagens poderão então ser visualizadas no **[Canal de Fotos](#canal-de-fotos)** do PSBBN

**[OSDMenu 1.2.0:](#osdmenu-mbr)**
- Tanto o **[OSDMenu MBR](#osdmenu-mbr)** quanto o **[HOSDMenu](#hosdmenu)** foram atualizados para a versão 1.2.0. O registro de alterações pode ser encontrado **[aqui](https://github.com/pcm720/OSDMenu/releases)**
- O aplicativo **OSDMenu Configurator** foi adicionado. Ele permite que você personalize o console PS2 modificando as configurações do **[OSDMenu MBR](#osdmenu-mbr)** e do **[HOSDMenu](#hosdmenu)**
- O **OSDMenu Configurator** será instalado na próxima vez que você selecionar **[Instalar Jogos e Aplicativos](#instalar-jogos-e-aplicativos)** a partir do **[Menu Principal](#menu-principal)** do PSBBN Definitive Project. Ele pode ser iniciado a partir da **[Coleção de Jogos](#coleção-de-jogos)** ou do **[HOSDMenu](#hosdmenu)**

**[Instalações apenas com o HOSDMenu:](#instalar-apenas-o-hosdmenu)**
- Aumentado o tamanho máximo da partição do **[POPS](#popstarter)** para 130 GB.
- Adicionada a seleção de idioma. O idioma selecionado é usado pelo instalador de jogos para os títulos dos jogos e para a **[mensagem IGR do POPS](#saindo-dos-jogos)**.
- Os usuários que possuem apenas o **[HOSDMenu](#hosdmenu)** agora podem alterar o idioma da instalação no **[Menu de Extras Opcionais](#extras-opcionais)**

**[Alterar Configurações de Tela:](#alterar-configurações-de-tela)**
- Anteriormente travado no **[PSBBN](#psbbn)**, agora você pode alterar as configurações de tela do sistema no menu **[Menu de Extras Opcionais](#extras-opcionais)** para 4:3, Completo ou 16:9
- **Note:** Essa configuração é utilizada por alguns jogos e pelo **[HOSDMenu](#hosdmenu)**. Ela não altera a proporção do próprio **[PSBBN](#psbbn)**

**[Limpar Cache de Artes e Ícones:](#limpar-cache-de-arte-e-icones)**
- No menu **[Menu de Extras Opcionais](#extras-opcionais)**, você agora tem a opção de limpar todas as artes e ícones baixados anteriormente que estão armazenados localmente no PC
- Você pode querer limpar o cache se os jogos exibirem artes incorretas ou de baixa qualidade, já que artes atualizadas podem estar disponíveis
- Executar o **[Instalador de Jogos](#instalar-jogos-e-aplicativos)** fará o download das artes e ícones mais recentes

**[PSBBN Launcher for Windows:](#instalando-no-windows)**
- Adicionado suporte para instalação de jogos a partir de uma unidade de rede
- Adicionado um aviso que exibe os arquivos suportados para o **[Instalador de Filmes](#instalar-filmes)** e o **[Instalador de Fotos](#instalar-fotos)**
- Corrigida a mensagem de aviso sobre a capacidade mínima da unidade
- Correções de bugs

**Correções de Bugs e Melhorias:**
- Ativado o logotipo do PS2 ao iniciar discos de jogos físicos de PS2 em instalações limpas. Usuários que estão atualizando podem ativar essa opção usando o **OSDMenu Configurator**. Usuários do **[MechaPwn](https://github.com/MechaResearch/MechaPwn)** agora podem iniciar mídias importadas e discos master sem pular o logotipo do PlayStation 2 ou se deparar com uma tela de logotipo corrompida
- Ao **[reatribuir os botões Cruz e Círculo](#reatribuir-botões-cruz-e-círculo)**, sua preferência agora é salva e não é mais resetada ao instalar atualizações
- Melhorada a extração do ID do título a partir de arquivos VCD
- O Instalador do PSBBN exibe os requisitos de tamanho típicos para músicas e filmes ao criar partições 
- Um arquivo de log separado é usado durante a instalação e atualização
- Corrigida a extração de arquivos PSU quando os nomes das pastas excedem 12 caracteres
- Corrigido um problema com o **[atalho do Menu Navigator](#coleção-de-jogos)** sendo removido após a reinicialização
- Corrigidos os cálculos de capacidade e espaço disponível para unidades menores que 128 GB
- Adicionado um atraso entre a desmontagem e a montagem de sistemas de arquivos para melhorar a confiabilidade
- Corrigido o rastreamento de erros para o SQLite
- Downloads de artes aprimorados para aplicativos `SAS` e `ELF`
</details>

<details>
<summary><b>08 de janeiro de 2026 - PSBBN Definitive Project: Novo Nome e Suporte Multilíngue</b></summary>
<p></p>

[![PSBBN Definitive Project: Novo Nome e Suporte Multilíngue](https://github.com/user-attachments/assets/32bb93f2-c009-4b82-ba62-67933ff30e83)](https://www.youtube.com/watch?v=dvCt_ExHwro)

O PSBBN Definitive English Patch começou sua trajetória em 2023 como um patch de idioma Inglês para o PSBBN, e este trabalho expandiu-se continuamente bem além de seu escopo original. Daqui para frente, ele será coletivamente chamado de **PSBBN Definitive Project**.

O PSBBN agora está disponível em Inglês, Alemão, Italiano e no Japonês original, com a tradução em Francês chegando em breve. Você poderá escolher o idioma ao instalar o PSBBN. O idioma também pode ser alterado posteriormente no menu **[Menu de Extras](#extras-opcionais)**.

Quando o idioma está definido como Japonês, os títulos dos jogos da região Japonesa são exibidos em Japonês e classificados na ordem 'gojūon' (五十音) tanto na **[Coleção de Jogos](#coleção-de-jogos)** quanto no **[Navegador do HOSDMenu](#hosdmenu)**. Além disso, os canais online japoneses originais também estão acessíveis a partir do **[Canal de Internet](#canal-de-internet)**.

**Notas completas de lançamento**  

- **NOVO!** Tradução do PSBBN para o alemão feita por [Argo707](https://github.com/Argo707)  
- Tradução para o Inglês aprimorada  
- Canais online Japoneses originais restaurados

**[Instalador do PSBBN:](#instalar-psbbn-e-hosdmenu)**
- Adicionada a opção de selecionar um idioma ao instalar o PSBBN
- Selecionar o Japonês também instalará os **[canais online](#canal-de-internet)** japoneses originais

**[Atualizar Software do PSBBN:](#atualizar-software-do-sistema-do-ps2)**
- Agora atualiza o software de sistema do PSBBN e o pacote de idiomas para a versão mais recente
- Quando o idioma está definido como Japonês, os canais online também são atualizados

**[Extras Opcionais:](#extras-opcionais)**
- Adicionada a opção de alterar o idioma do PSBBN no menu **[Extras Opcionais](#extras-opcionais)**

**[Instalador de Jogos:](#instalar-jogos-e-aplicativos)**
- Quando o idioma estiver definido como Japonês, os títulos dos jogos da região Japonesa serão exibidos em Japonês e classificados na ordem 'gojūon' (五十音)
- A mensagem IGR do POPS é instalada correspondendo ao idioma selecionado
- Os manuais dos jogos de PS1 são instalados correspondendo ao idioma selecionado

**`TitlesDB_PS1.csv` e `TitlesDB_PS2.csv`:**  
- Adicionados títulos de jogos japoneses para todos os jogos da região Japonesa

**`list-builder.py`:**
- Atualizado para lidar com títulos de jogos em Japonês

**PSBBN Definitive Patch atualizado para a versão v4.1.0**
- Atualizado o link para o novo Canal Konami em instalações não Japonesas
- Modificado o arquivo `fstab` para montar a partição `channels`

**Geral**:  
- O idioma do sistema agora é definido para o idioma selecionado do PSBBN e não é mais resetado para o Inglês ou Japonês ao iniciar o PSBBN
- Adicionados `libicu-dev` e `pkg-config` às dependências
- Mensagem IGR em Inglês do POPS aprimorada
- Adicionado um aviso para impedir que os scripts internos sejam executados diretamente
- Adicionada uma verificação de validação de instalação para abortar instalações não suportadas
- O **[NHDDL](#nhddl)** foi atualizado para a versão 1.2.1
</details>

<details>
<summary><b>14 de novembro de 2025 - PSBBN Definitive Patch v4.0 - OSDMenu, adaptadores de HDD de terceiros e Mais!</b></summary>
<p></p>

[![PSBBN Definitive Patch v4.0 - OSDMenu, adaptadores de HDD de terceiros e Mais!](https://github.com/user-attachments/assets/1a3f2d69-6bec-4fe4-aa27-c367f5d98f98)](https://www.youtube.com/watch?v=fT368C90Trc)

**[NOVO! OSDMenu MBR:](#osdmenu-mbr)**  
Substituído o aplicativo MBR original da Sony pelo **[OSDMenu MBR](#osdmenu-mbr)**, uma alternativa homebrew que:
- Gerencia a inicialização de jogos e aplicativos diretamente, em vez de depender do **BBN Launcher (BBNL)**
- Melhora a velocidade de boot do sistema
- Os jogos agora iniciam até 6 segundos mais rápido
- Elimina a necessidade do **PlayStation 2 Basic Boot Loader (PS2BBL)** — o **[OSDMenu MBR](#osdmenu-mbr)** suporta nativamente a inicialização de ELFs segurando um botão do controle durante a inicialização, reduzindo drasticamente os tempos de boot se comparado ao **PS2BBL**
- O PS2 Linux agora é inicializado diretamente segurando o botão ○ ao ligar o console, em vez de interromper a inicialização do **[PSBBN](#psbbn)**
- Removido o aplicativo **"Launch Disc"** — basta inserir um disco de jogo para jogar, com suporte a **[ID do Jogo, MechaPwn e PS1VmodeNeg embutido!](#executar-discos-de-jogos-de-ps1-e-ps2)**
- Melhora o manuseio do **[Retro GEM ID do Jogo](#id-do-jogo)** — o **[PSBBN](#psbbn)** e o **[HOSDMenu](#hosdmenu)** agora definem um **ID do Jogo** na inicialização, eliminando a necessidade do **Retro GEM ID do Jogo Resetter**
- Ao usar um **MemCard Pro 2 ou SD2PSX**, **VMCs** desnecessários não são mais gerados ao iniciar jogos de PS1 com o **[POPStarter](#popstarter)** ou outros aplicativos homebrew

**[NOVO! HOSDMenu:](#hosdmenu)**  
Aplica correções no **HDD-OSD** e introduz diversas melhorias:
- Suporte a unidades maiores — anteriormente limitado a 1 TB
- Inicia aplicativos homebrew diretamente a partir do menu do **OSDSYS**
- Inicia **[aplicativos compatíveis com o SAS](#save-application-system-sas)** a partir de Memory Cards e da unidade interna no **[Browser 2.0](#hosdmenu)**
- Suporte para inicializar aplicativos a partir de MMCE, MX4SIO, UDPBD, dispositivos iLink e HDDs formatados em APA e exFAT
- GSM integrado para jogos em disco e aplicativos
- Suporte para resoluções de 1080i e 480p
- E mais — veja o [repositório no GitHub](https://github.com/pcm720/OSDMenu) para detalhes completos

**[NOVO! Instalar PSBBN e HOSDMenu:](#instalar-psbbn-e-hosdmenu)**
- O Instalador do PSBBN agora instala o **[HOSDMenu](#hosdmenu)** junto com o **[PSBBN](#psbbn)**
- Exibe as notas de lançamento mais recentes ao instalar e atualizar
- Suporta unidades menores — capacidade mínima reduzida de 200 GB para 32 GB
- Aumentado o tamanho máximo da partição APA para 112 GB
- Após o particionamento, qualquer espaço não alocado agora é atribuído à partição do **[OPL](#open-ps2-loader-opl)**
- Alerta os usuários para verificarem o [archive.org](https://archive.org/) ou utilizarem uma VPN se os downloads falharem

**[NOVO! Instalar Apenas o HOSDMenu:](#instalar-apenas-o-hosdmenu)**
- Adiciona uma opção para instalar apenas o **[HOSDMenu](#hosdmenu)** (para usuários com adaptadores de HDD de terceiros)
- Cria uma partição **[POPS](#popstarter)** com tamanho personalizado (até 118 GB), alocando automaticamente o espaço restante para a partição do **[OPL](#open-ps2-loader-opl)** (até 2 TB)

**[Instalador de Jogos:](#instalar-jogos-e-aplicativos)**
- O **[Instalador de Jogos](#instalar-jogos-e-aplicativos)** agora requer o **PSBBN Definitive Project v4.0.0** ou superior, ou a instalação apenas do **[HOSDMenu](#instalar-apenas-o-hosdmenu)**.
- Adiciona suporte para configurações exclusivas do **[HOSDMenu](#hosdmenu)**
- Atualiza o **[OSDMenu MBR](#osdmenu-mbr)** e o **[HOSDMenu](#hosdmenu)** caso versões mais recentes estejam disponíveis
- Atualiza o **Menu Navigator** com atalhos para o iniciador de jogos selecionado (**[OPL](#open-ps2-loader-opl)** ou **[NHDDL](#nhddl)**), **[HOSDMenu](#hosdmenu)** e **[wLaunchELF_ISR](#wlaunchelf_isr)**
- Atualiza a configuração do **[HOSDMenu](#hosdmenu)** para exibir os aplicativos homebrew instalados no menu do **OSDSYS**
- Converte automaticamente arquivos `BIN/CUE` de PS1 para `VCD` e arquivos `BIN/CUE` de PS2 para `ISO`
- Os jogos de PS1 agora são copiados e sincronizados através do `PFS FUSE` usando o `rsync`, exibindo o progresso durante a transferência
- Copia apenas arquivos válidos de jogos e homebrew ao sincronizar ou adicionar jogos e aplicativos — o `rsync` agora ignora os arquivos de metadados `:Zone.Identifier` do Windows, que poderiam causar falhas na sincronização
- Coloca automaticamente as extensões `.VCD` minúsculas em letras maiúsculas para garantir a compatibilidade com o **[POPStarter](#popstarter)**
- Realocados os arquivos `OPNPS2LD.ELF` e `nhddl.elf` para `__system/launcher` e o arquivo `POPSTARTER.ELF` para `__common/POPS` a partir do exFAT

**`list-builder.py`:**
- Agora verifica a partição PFS `__.POPS` em busca de arquivos `VCD` em vez da pasta `POPS` local

**`art_downloader.py`:**
- O `art_downloader` foi convertido de JavaScript para Python, removendo as dependências de Node.js, npm, Puppeteer e Chromium

**[Instalar Música:](#instalar-música)**
- Adiciona suporte para álbuns de vários discos usando os números dos discos a partir dos metadados
- Usa os metadados de **Artista do Álbum** para álbuns e os metadados de **Artista** para faixas individuais
- Substitui caracteres não suportados nos metadados por alternativas seguras
- Agrupa claramente os arquivos ignorados pelo motivo da recusa

**[Instalador do PS2 Linux:](#install-ps2-linux)**
- Atualiza a configuração do **[OSDMenu MBR](#osdmenu-mbr)** para ativar a inicialização do PS2 Linux.

**[PSBBN Launcher for Windows:](#instalando-no-windows)**
- Capacidade mínima do disco reduzida de 200 GB para 32 GB
- Os avisos ao usuário agora são mais descritivos
- Impede que os usuários selecionem uma pasta do WSL para armazenar os jogos e mídias
- Exige a build 19041 como a versão mínima do Windows necessária para executar o WSL
- Executa o comando `wsl --install --no-distribution` para garantir que o WSL 2 esteja disponível
- Usa explicitamente o WSL 2 ao instalar a distribuição do PSBBN
- Verifica se o apt instalou o git com sucesso; caso contrário, encerra o processo de forma segura
- A entrada do número do disco foi atualizada para suportar valores maiores que 9
- Encerra de forma segura se a montagem do disco falhar

**[NHDDL:](#nhddl)**
- Atualizado para a versão v1.2.0

**`Setup.sh` e `flake.nix`:**
- Adicionado o `bchunk` às dependências

**Arquivo Tar do Definitive Patch 4.0.0:**
- Corrige as permissões e a propriedade dos arquivos
- Removidos arquivos em cache e outros excessos desnecessários, reduzindo o tamanho do arquivo
- Adicionadas pastas extras para os arquivos do **[HOSDMenu e HDD-OSD](#hosdmenu)**
- Substituído o arquivo **osdboot.elf** criptografado pela versão não criptografada

**Geral:**
- Adicionado suporte para sistemas ARM64. Testado em um Raspberry Pi executando a última versão do Raspberry Pi OS
- `BOOT.ELF` substituído pela versão do [wLaunchELF_ISR](#wlaunchelf_isr) v4.43x_isr-bb13043, compatível com o [SAS](#save-application-system-sas)
- Removido o arquivo `PS1VModeNeg.elf`
- Altera a configuração de localidade (locale) de `en_US.UTF-8` para `C.UTF-8` (alguns sistemas não possuíam o `en_US.UTF-8`), garantindo que a saída do script e os logs permaneçam em Inglês e evitando falhas relacionadas
- Melhoria no manuseio de montagem e desmontagem de partições APA
- Correções de bugs
- Adicionadas licenças de software

</details>

<details>
<summary><b>09 de setembro de 2025 - PSBBN Launcher for Windows: Instalação e Configuração Fáceis</b></summary>
<p></p>

[![PSBBN Launcher for Windows: Instalação e Configuração Fácil](https://github.com/user-attachments/assets/981e4abc-10b0-49d2-8d52-3e19ea80650b)](https://www.youtube.com/watch?v=O5ZvJoW4oNw)

**[NOVO! PSBBN Launcher For Windows](#instalando-no-windows)** - A nova forma de instalar o **PSBBN Definitive Project** no Windows 10 e 11.  
Um agradecimento especial ao Yornn por todo o seu trabalho nesse recurso.

</details>

<details>
<summary><b>28 de agosto de 2025 - PSBBN Definitive Patch v3.00 - Instalador de Música, Sistema de Menus, Instalações Mais Rápidas e Mais!</b></summary>
<p></p>

[![PSBBN Definitive English Patch 3.0](https://github.com/user-attachments/assets/3b82d809-28d5-4675-87c2-c7f1abf96ae6)](https://www.youtube.com/watch?v=lUMKZck6G08) 
  
**[NOVO! Sistema de Menus:](#menu-principal)**
- Novo sistema de menu centralizado no lugar de scripts separados, facilitando a navegação entre os diversos recursos do **PSBBN Definitive Project**
- A configuração agora é executada automaticamente caso sejam detectadas dependências ausentes

**[NOVO! Instalador de Música:](#instalar-música)**
- Instala músicas para reprodução no **[Canal de Música do PSBBN](#canal-de-música)**. Formatos suportados: `.mp3`, `.m4a`, `.flac` e `.ogg`

**[NOVO! Instalador do PSBBN:](#instalar-psbbn-e-hosdmenu)**
- O **[PSBBN](#psbbn)** fez a transição completa do ReiserFS (um sistema de arquivos antigo e não mais suportado) para o ext2, permitindo acesso direto a todas as partições do BBN
- O novo Instalador do PSBBN funciona com um arquivo tar em vez de uma imagem de disco, reduzindo o tamanho do download e melhorando drasticamente o tempo de instalação
- Durante a instalação, você pode definir um tamanho personalizado para a partição `contents` usada para filmes e fotos (anteriormente limitada a 5 GB)
- Aumentado o tamanho máximo das partições de Música, Conteúdos e POPS — agora até 111 GB

**[NOVO! Atualizador do PSBBN:](#atualizar-software-do-sistema-do-ps2)**
- Permite atualizar para a versão mais recente do Definitive Project diretamente a partir do menu. Não é necessário o uso de um pen drive ou teclado USB!

**[Instalador de Jogos:](#instalar-jogos-e-aplicativos)**
- O instalador de jogos agora oferece uma correção para HDTV em jogos de PS1, permitindo que eles sejam exibidos em TVs que não suportam a resolução de 240p
- Correções de bugs e melhoria na extração de ID do Jogo para arquivos ISO e VCD.  
- Extrai o ID do Jogo diretamente dos arquivos ZSO ao descompactar apenas uma parte da imagem do disco; não é mais necessário descompactar totalmente os arquivos ZSO nem renomeá-los, melhorando significativamente o tempo de processamento

**[Extras:](#extras-opcionais)**
- O PS2 Linux agora é uma instalação opcional. Você pode definir um tamanho personalizado para a partição home. O PS2 Linux também pode ser reinstalado caso você enfrente problemas
- Altere as funções dos botões Cruz e Círculo no controle. Escolha entre o layout padrão (Cruz = Confirmar, Círculo = Voltar) ou o layout alternativo (Círculo = Confirmar, Cruz = Voltar)

**HDD-OSD (Browser 2.0):**
- Novo ícone do PSBBN projetado pelo Yornn
- Nova cor de fundo aprimorada ao visualizar os ícones dos jogos

</details>

<details>
<summary><b>17 de julho de 2025 - Definitive Patch v2.11 - Segurança de Inicialização Corrigida! Troca de Botões, Grupos VMC e Mais!</b></summary>
<p></p>

[![PSBBN Definitive Patch v2.11](https://github.com/user-attachments/assets/49511803-429b-4cd8-8546-40334be3f244)](https://www.youtube.com/watch?v=kgXe8rlqsr0)

**PSBBN Atualizado para o Definitive Patch v2.11**

O patch v2.11 pode ser instalado executando o [script do Instalador do PSBBN](#instalar-psbbn-e-hosdmenu) (todos os dados serão perdidos) ou através da nova opção **Atualizar Software do PSBBN** no [script de Extras](#extras-opcionais).

**Novidades no Definitive Patch v2.11:**
- Segurança de Inicialização Corrigida. A verificação de segurança do CRC no boot ELF do PSBBN foi burlada, permitindo o carregamento de kernels customizados.
- Os botões × e ○ foram trocados: × agora é Enter, e ○ agora é Voltar.
- Adicionado suporte para o controle remoto de DVD do PlayStation 2. Os botões `PLAY`, `PAUSE`, `STOP`, `PREV`, `NEXT`, `SCAN` e `DISPLAY` agora podem ser usados durante a reprodução de músicas e filmes nos canais de [Música](#canal-de-música) e [Filmes](#canal-de-filmes). O botão `ENTER` também pode ser utilizado na navegação dos menus.
- O **Guia do PlayStation BB** foi atualizado para refletir a troca de botões e a realocação da [Coleção de Jogos](#coleção-de-jogos). Uma nova seção foi adicionada abordando os Canais Online. Diversas melhorias na tradução para o Inglês.
- Melhora o processo de atualização. O uso de um pen drive e teclado USB não será necessário para futuras atualizações.

**`02-PSBBN-Installer.sh`:**
- Agora você pode definir um tamanho personalizado para a partição [POPS](#popstarter). Anteriormente, ela preenchia todo o espaço restante após a criação da partição de música.

**`03-Game-Installer.sh`, `ps2iconmaker.sh` e `txt_to_icon_sys.py`:**

- Jogos de PS1 com vários discos agora suportam a troca de discos sem configurações adicionais. Um arquivo `DISCS.TXT` é criado para cada jogo de vários discos. Jogos de vários discos agora também compartilham um [Memory Card Virtual do POPStarter (VMC)](#memory-cards-virtuais)
- [Grupos VMC do POPStarter](#memory-cards-virtuais) para jogos de PS1: jogos que podem interagir com os dados de salvamento de outros jogos agora compartilham um único VMC. Por exemplo, as licenças obtidas no Gran Turismo podem ser transferidas para o Gran Turismo 2, e o Psycho Mantis do Metal Gear Solid pode comentar sobre outros jogos da Konami que você tenha jogado.
- As VMCs agora exibem títulos mais claros em **Gerenciamento de Dados Salvos** e no **Browser 2.0** com ícones personalizados para cada jogo e grupo.
- O instalador de jogos agora gera automaticamente os ícones do HDD-OSD (Browser 2.0) caso não os encontre no [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database). Se as imagens da capa de um jogo estiverem disponíveis no Banco de Dados de Artes do OPL Manager, um ícone 3D para o jogo será gerado automaticamente. Ícones 3D também são criados para as VMCs quando o logotipo de um jogo estiver disponível. Todos os ícones gerados recentemente são enviados automaticamente para o HDD-OSD Icon Database, e os ícones ausentes são relatados.
- Corrigido um erro em que informações incorretas de publicação poderiam ser exibidas para arquivos `ELF`

**`list-builder.py`:**

- Melhorada a extração de ID do Jogo para casos atípicos. Agora lida com IDs fora do padrão, como `LSP99016.101`, e jogos de PS1 com arquivos `system.cnf` não padronizados.

**Neutrino Atualizado para a Versão 1.7.0**

- O registro de alterações completo do Neutrino pode ser encontrado [aqui](https://github.com/rickgaiser/neutrino/releases/tag/v1.7.0)

**Open PS2 Loader Atualizado para a versão v1.2.0 Beta-2210-6b300b0**
- Adiciona suporte a Grupos VMC e correções de bugs.

**wLaunchELF**
- Atualizado para a versão [wLaunchELF v4.43x_isr](#wlaunchelf_isr). Melhora a estabilidade e adiciona suporte ao sistema de arquivos exFAT em unidades externas e ao MMCE (navegação em cartões SD no MemCard Pro 2/SD2PSX).

</details>

<details>
<summary><b>05 de junho de 2025 - PSBBN Definitive Patch v2.10 – Grandes Mudanças no Instalador de Jogos e Mais!</b></summary>
<p></p>

[![PSBBN Definitive Patch v2.10](https://github.com/user-attachments/assets/ff4e6e5b-8556-4fe2-88b2-99e7eb09121c)](https://www.youtube.com/watch?v=XTacIPOGAwE)

**PFS Shell.elf e HDL Dump.elf:**

- O PFS Shell foi atualizado para suportar a criação de partições APA de 8 MB
- O HDL Dump foi atualizado para modificar corretamente os cabeçalhos das partições

**Imagem de Disco do PSBBN Atualizada para a Versão 2.10:**

- O disco foi criado com uma nova versão do PFS Shell para total compatibilidade com partições APA de 8 MB 
- Adicionado um link direto para a [Coleção de Jogos](#coleção-de-jogos) no Menu Principal  
- Melhoria no tempo de inicialização para os usuários sem um cabo Ethernet conectado  
- O script de inicialização foi modificado para formatar e inicializar a partição de Música, permitindo que ela seja menor ou maior do que antes.
- Reduzido o atraso antes que os pressionamentos de botão sejam registrados ao inicializar o Linux  
- A partição do PS2 Linux agora usa o sistema `ext2` em vez do `reiserfs`   
- Removidas as Configurações de Provedor de Internet (ISP) do Menu Principal  
- O atalho para o Open PS2 Loader foi removido do Menu Navigator (o usuário agora pode adicionar manualmente um atalho para o iniciador de jogos de sua preferência)
- Atalhos modificados para o [LaunchELF](https://github.com/ps2homebrew/wLaunchELF) e para o [Launch Disc](#launch-disc)
- Atualizada a página 'Sobre o PlayStation BB Navigator'  
- Ativado o acesso via telnet ao PSBBN para fins de desenvolvimento  
- Correções na tradução para o Inglês  

**`02-PSBBN-Installer.sh`:**

- Impede que o script instale o PSBBN Definitive Patch caso a versão seja inferior à 2.10  
- Particiona o espaço restante dos primeiros 128 GB da unidade:
  - A partição de Música agora pode variar entre 1 GB e 104 GB  
  - A partição [POPS](#popstarter) agora pode variar entre 1 GB e 104 GB  
  - O espaço é reservado para 800 **partições BBNL**  
- O instalador do [POPS](#popstarter) foi removido (agora é gerenciado pelo script do Instalador de Jogos)  
- O código foi substancialmente limpo e otimizado  

**`03-Game-Installer.sh`:**

- Adicionado um aviso aos usuários que estiverem executando o PSBBN Definitive Patch inferior à versão 2.10
- A unidade do PS2 agora é detectada automaticamente  
- Adicionada uma opção para definir um caminho personalizado para a pasta `games` no PC
- Permite a adição de novos jogos e aplicativos sem a necessidade de realizar uma sincronização completa  
- O tamanho da partição do **BBNL** foi reduzido de 128 MB para 8 MB, permitindo que até 800 jogos/aplicativos sejam exibidos na [Coleção de Jogos](#coleção-de-jogos)
- Corrigido um erro que impedia o lançamento de jogos com números sobrescritos nos títulos  
- Melhorias gerais na verificação de erros e mensagens  
- Corrigidos os problemas de detecção de sucesso/falha em alguns comandos do `rsync`  
- O `rsync` agora é executado somente quando necessário  
- Processo de atualização aprimorado para o [POPStarter](#popstarter), [OPL](#open-ps2-loader-opl), [NHDDL e Neutrino](#nhddl)
- O Instalador de Jogos agora instala os binários do [POPS](#popstarter) caso estejam ausentes  
- O número de comandos executados com o `sudo` foi reduzido  
- Os arquivos `ELF` agora são instalados em pastas e incluem um arquivo `title.cfg`  
- O código foi substancialmente limpo e otimizado  

**`list-builder.py`:**

- Os scripts `list-builder-ps1.py` e `list-builder-ps2.py` foram unificados em um único script  
- Agora realiza a extração dos IDs de jogo para os jogos de PS1 e de PS2  

**`list-sorter.py`:**

- A lógica de classificação dos jogos foi transferida dos scripts antigos para este script  
- A classificação foi melhorada de forma significativa  

**Geral**

- Os scripts do Instalador do PSBBN e do Instalador de Jogos agora impedem que o PC entre em modo de suspensão durante a execução  
- Foi adicionada uma verificação a cada script para assegurar que ele está sendo executado no Bash  
- O arquivo **README.md** foi atualizado

</details>

<details>
<summary><b>01 de maio de 2025 - SAS, HDD-OSD, PS2BBL e Mais!</b></summary>

[![SAS, HDD-OSD, PS2BBL e Mais!](https://github.com/user-attachments/assets/be5b32d2-665c-4505-aefe-3c9ab864f72a)](https://www.youtube.com/watch?v=vpbHlS8nY58)

- Adicionado suporte ao [Save Application System (SAS)](#save-application-system-sas). Os arquivos `PSU` agora também podem ser colocados na pasta local `games/APPS` do PC e serão instalados pelo script `03-Game-Installer.sh`
- Suporte ao HDD-OSD foi adicionado ao script `03-Game-Installer.sh`. Os ícones 3D agora são baixados através do [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database)
- Novo script: [04-Extras.sh](#extras-opcionais). Adicionada a capacidade de instalar o HDD-OSD e o [PlayStation 2 Basic Boot Loader (PS2BBL)](#playstation-2-basic-boot-loader-ps2bbl)
- Crie os seus próprios ícones para o HDD-OSD usando os [Modelos de Ícones do HDD-OSD](https://github.com/CosmicScale/HDD-OSD-Icon-Database/releases/download/v1.0.0/HDD-OSD-Icon-Templates.zip)
- Traduza o PSBBN através do [Pacote de Tradução](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/issues/299) para localizar o software em vários idiomas.

</details>

<details>
<summary><b>28 de março de 2025 - Homebrew Launcher e Mais!</b></summary>
<p></p>

[![Homebrew Launcher e Mais!](https://github.com/user-attachments/assets/57e7842c-f5b5-46b0-950e-246eebfb0e4a)](https://www.youtube.com/watch?v=q9LvE_OPIPo)

- O [Open PS2 Loader](#open-ps2-loader-opl) foi atualizado para a versão 1.2.0-Beta-2201-4b6cc21:
  - O modo máximo de UDMA do BDM foi limitado a UDMA4 para prevenir problemas de compatibilidade com diversos adaptadores SATA/IDE2SD
- Um manual para jogos de PS1 foi adicionado. Ele pode ser acessado na [Coleção de Jogos](#coleção-de-jogos) ao selecionar um jogo, apertar **△** e, em seguida, selecionar **Manual**
- Houve a transição para a versão 2.0 do **BBN Launcher (BBNL)**:
  - O suporte ao PFS foi removido, sendo priorizado o carregamento do [OPL](#open-ps2-loader-opl), [POPStarter](#popstarter), [Neutrino](#nhddl) e dos arquivos de configuração diretamente da partição exFAT para otimizar o processo de inicialização.
  - O **BBNL** foi transferido para o cabeçalho APA, melhorando ainda mais a velocidade de carregamento.
  - Removida a dependência dos arquivos `ELF` renomeados do [POPStarter](#popstarter) para lançar as VCDs do PS1; agora, o [POPStarter](#popstarter) é carregado de forma direta com um argumento de boot.
  - O [NHDDL](https://github.com/pcm720/nhddl) agora inicia em modo ATA, otimizando o tempo de boot do sistema e prevenindo a ocorrência de potenciais mensagens de erro.
- O [Neutrino](#nhddl) foi atualizado para a versão 1.6.1
- O [NHDDL](#nhddl) foi atualizado para a versão MMCE + HDL Beta 4.17
- Adicionadas as capas através dos backups da [Base de Dados de Arte do OPL Manager](https://oplmanager.com/site/index.php?backups). Agora, a arte dos jogos do PS2 é mostrada no OPL/NHDDL
- Suporte a homebrews foi implementado no script `03-Game-Installer.sh`. Arquivos `ELF` inseridos na pasta local `games/APPS` do computador serão processados e exibidos tanto na [Coleção de Jogos](#coleção-de-jogos) do PSBBN quanto na seção de Apps do OPL
- Os aplicativos agora suportam o [ID do Jogo](#id-do-jogo) para uso com o Pixel FX Retro GEM, MemCard Pro e SD2PSX

</details>

<details>
<summary><b>19 de fevereiro de 2025 - BBN Launcher, Neutrino e NHDDL</b></summary>
<p></p>

[![BBN Launcher, Neutrino e NHDDL](https://github.com/user-attachments/assets/8007d102-3019-4037-8c52-24d1454777da)](https://www.youtube.com/watch?v=0vpSiAa6ITc)

- O script [OPL-Launcher-BDM](https://github.com/CosmicScale/OPL-Launcher-BDM) foi substituído pelo novo **BBN Launcher (BBNL)**
- Foi adicionado suporte ao [Neutrino](#nhddl). Agora é possível selecionar o [Open PS2 Loader](#open-ps2-loader-opl) ou o [Neutrino](#nhddl) como o carregador principal dos jogos
- Ao selecionar o Neutrino como inicializador de jogos padrão, o [NHDDL](#nhddl) pode ser utilizado para aplicar configurações individuais por jogo

</details>

<details>
<summary><b>22 de janeiro de 2025 - ID do Jogo, Base de Dados de Artes do PSBBN, Tutorial Atualizado e Mais!</b></summary>

[![ID do Jogo, Banco de Dados de Arte do PSBBN, Tutorial Atualizado e Mais!](https://github.com/user-attachments/assets/1bae03fe-b3eb-447e-99da-8f184279a848)](https://www.youtube.com/watch?v=sHz0yKYybhk)

- Implementado o suporte a [ID do Jogo](#id-do-jogo) para o Pixel FX Retro GEM, bem como para o MemCard Pro 2 e SD2PSX. Funciona em jogos de PS1 e de PS2
- Os jogos de PS2 agora inicializam de forma mais ágil, com um ganho de até 5 segundos no boot
- Solucionado o conflito com dispositivos de armazenamento de massa (USB, iLink, MX4SIO). Agora, os jogos iniciam corretamente mesmo com esses equipamentos conectados
- Os aplicativos agora são atualizados de forma automática quando você sincroniza os jogos
- O utilitário de download de artes foi aprimorado, permitindo baixar um número consideravelmente maior de imagens
- Tratamento de erros otimizado no script de instalação do PSBBN
- O script de configuração passou por alterações para rodar corretamente, sem apresentar falhas, em ambientes Linux live
- Suporte estendido para abranger distribuições Linux baseadas no Arch e no Fedora, além da compatibilidade existente com o Debian
- Foram introduzidas etapas de confirmação no script do instalador do PSBBN antes de efetuar a criação de partições
- Atualização da imagem do PSBBN para a versão 2.01:
  - Definido o padrão do teclado USB para o idioma Inglês (EUA). Aperte as teclas `ALT+~` para alternar entre as entradas kana e direta
  - Pequenos ajustes efetuados na tradução para a língua inglesa
- O [Open PS2 Loader](#open-ps2-loader-opl) e o utilitário [Launch Disc](#launch-disc) foram integrados à [Coleção de Jogos](#coleção-de-jogos)
- O script de Instalação de Jogos passou por atualizações e agora cria e remove as partições dos jogos dinamicamente conforme necessário. Diga adeus aos inconvenientes banners de "Em breve..."!
- Arquivos inseridos nas pastas `CFG`, `CHT`, `LNG`, `THM` e `APPS` locais do computador serão agora transferidos para a unidade do PS2 durante o processo de sincronização dos jogos
- Agora, os scripts são atualizados automaticamente quando uma nova versão se encontra disponível
- Obras de arte otimizadas
- Apresentamos a base de dados oficial de artes: [PSBBN art database](https://github.com/CosmicScale/psbbn-art-database)
- Caso a arte não seja localizada no [PSBBN art database](https://github.com/CosmicScale/psbbn-art-database), será feita uma tentativa de obtê-la a partir da IGN. Downloads provenientes da IGN são transferidos de forma automática para colaborar com o [PSBBN art database](https://github.com/CosmicScale/psbbn-art-database), e a falta de artes também gera um relatório automático. Envio manual de artes é encorajado; confira a página oficial do [PSBBN art database no GitHub](https://github.com/CosmicScale/psbbn-art-database) para mais informações

</details>

<details>
<summary><b>11 de dezembro de 2024 - PSBBN Definitive English Patch 2.0</b></summary>
<p></p>

[![PSBBN Definitive English Patch 2.0](https://github.com/user-attachments/assets/608c9430-25d8-4918-8111-023eac16ab62)](https://www.youtube.com/watch?v=ooH0FjltsyE)

- Versão inaugural do patch 2.0
- Os canais online da Bandai e SCEI foram incorporados ao Game Channel
- Suporte ao sistema dual-boot para PS2 Linux
- O [wLaunchELF](https://github.com/ps2homebrew/wLaunchELF) vem pré-instalado na versão
- Compatibilidade para discos rígidos maiores: sem mais a limitação de 128 GB de armazenamento
- Inclusão do sistema [APA-Jail](#apa-jail), viabilizando que as partições APA do PlayStation operem em conjunto com uma partição exFAT
- Introdução do [OPL-Launcher-BDM](https://github.com/CosmicScale/OPL-Launcher-BDM), tornando possível carregar os jogos do PS2 armazenados na partição exFAT de forma direta pelo PSBBN
- Adoção do script do [Instalador do PSBBN](#instalar-psbbn-e-hosdmenu):
  - Faz a instalação do PSBBN, binários do [POPS e POPStarter](#popstarter)
  - Executa o particionamento dos primeiros 128 GB da unidade usando o formato APA:
    - Permite a criação de um máximo de 700 partições para o launcher do OPL
    - Possibilita criar uma partição de música com tamanho customizável, partindo de 10 GB até 97 GB
    - O espaço que sobra é direcionado para a partição do [POPS](#popstarter), usada por jogos do PS1
  - Formata o restante do espaço da unidade além dos primeiros 128 GB criando uma partição exFAT, que servirá de armazenamento para os jogos do PS2
- Implementação do script para o [Instalador de Jogos](#instalar-jogos-e-aplicativos):
  - Automatiza todo o procedimento de instalação de jogos do PS1 e do PS2
  - Fica responsável por gerar todos os recursos e configurações dos metadados
  - Baixa, de forma automática, a arte dos jogos disponível no IGN

</details>  

# Guia de Instalação
O **PSBBN Definitive Project** foi totalmente localizado para Inglês, Japonês, Francês, Espanhol, alemão, Italiano e Português do Brasil. O idioma do sistema operacional é detectado automaticamente, e o projeto é executado nesse idioma, assumindo o Inglês como padrão caso não esteja disponível.

## Requisitos
Para a melhor experiência, recomenda-se um modelo PS2 Fat (séries SCPH-30000 a SCPH-55000).

**Requisitos mínimos:**
- Adaptador de HDD de terceiros
- HDD IDE ou SATA (mínimo de 32 GB[*](#problemas-conhecidos))

**Configuração recomendada:**
- Adaptador de Rede oficial da Sony
- Placa de atualização SATA Kaico ou BitFunx
- SSD SATA (256 GB a 2 TB)

**Notas:**
- Recomenda-se um SSD SATA para o [PSBBN](#psbbn), pois a maior velocidade de acesso aleatório resulta em uma resposta mais rápida dos menus.
- O [PSBBN](#psbbn) não suporta adaptadores de HDD de terceiros[*](#problemas-conhecidos). Adaptadores de terceiros são suportados apenas para a [instalação do HOSDMenu](#instalar-apenas-o-hosdmenu).
- O [PSBBN](#psbbn) e o [HOSDMenu](#hosdmenu) são compatíveis com os modelos PS2 Slim SCPH-700xx usando um IDE Resurrector (ou mod de hardware equivalente), e com os primeiros modelos de PS2 (séries SCPH-10000 a SCPH-18000) com um case de HDD externo oficial. [Uma configuração adicional é necessária para ambas as configurações](#consoles-antigos-scph-1000018000-e-slim-scph-700xx).

O **PSBBN Definitive Project** requer um PC x86-64 ou ARM64 para instalação. Conecte o HDD ou SSD ao PC via cabo SATA ou por meio de um adaptador USB.

## Instalando no Linux
Distribuições de 64 bits baseadas em Debian usando `apt`, distribuições baseadas em Arch usando `pacman` e distribuições baseadas em Fedora[*](#solução-de-problemas) usando `dnf` são suportadas. Sistemas baseados em Nix também são suportados via flakes. As distribuições recomendadas são Linux Mint, Debian e, para Raspberry Pi, o Raspberry Pi OS.

**O PSBBN Definitive Project é um lançamento contínuo (rolling release). Para receber atualizações automáticas e as últimas correções de bugs, você deve instalar os scripts usando `git clone`.**

Instale o git; para distribuições baseadas em Debian, execute:
```
sudo apt update
sudo apt install git
```
Clone o repositório:
```
git clone https://github.com/CosmicScale/PSBBN-Definitive-Project.git
```

Em seguida, acesse o diretório `PSBBN-Definitive-Project` e execute o script `PSBBN-Definitive-Patch.sh`:
```
cd PSBBN-Definitive-Project
./PSBBN-Definitive-Patch.sh
```
## Instalando no Windows
A maneira recomendada de instalar o **PSBBN Definitive Project** no Windows é usando o **PSBBN Launcher for Windows**. O **PSBBN Launcher for Windows** é compatível com as edições Home do Windows 10 e 11; outras edições podem não ser compatíveis. Para uma experiência sem problemas, certifique-se de que o Windows esteja totalmente atualizado.

**Tutorial em Vídeo:**

[![PSBBN Launcher for Windows: Instalação e Configuração Fácil](https://github.com/user-attachments/assets/981e4abc-10b0-49d2-8d52-3e19ea80650b)](https://www.youtube.com/watch?v=O5ZvJoW4oNw)

**Ativando a Virtualização:**  
Pode ser necessário ativar o Modo SVM (para CPUs AMD) ou VT-x (para CPUs Intel) nas configurações da BIOS, caso ainda não esteja ativado. Instruções de como fazer isso podem ser encontradas [aqui](https://www.elevenforum.com/t/enable-or-disable-cpu-virtualization-in-uefi-bios-firmware-settings-on-windows-pc.4928/).

Baixe o **PSBBN Launcher for Windows [aqui](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/releases/download/latest/PSBBN-Launcher-For-Windows.ps1)**.

**Defina a Política de Execução do PowerShell:**  
Antes de executar o script pela primeira vez, você deve alterar a política de execução no PowerShell:
1. Abra uma nova janela do PowerShell a partir do **menu Iniciar** pesquisando por **PowerShell** e selecione **Executar como Administrador**.
2. Digite o seguinte comando e pressione Enter:

```
Set-ExecutionPolicy -ExecutionPolicy Unrestricted
```

**Agora você está pronto para executar o script:**  
Clique com o botão direito em `PSBBN-Launcher-For-Windows.ps1` e selecione **Executar com o PowerShell**.

O script irá:
- Configurar automaticamente o **[Subsistema do Windows para Linux (WSL)](https://learn.microsoft.com/pt-br/windows/wsl/about)**
- Solicitar que você selecione a unidade de destino para instalar o **[PSBBN e HOSDMenu](#instalar-psbbn-e-hosdmenu)**, ou uma unidade que já tenha uma instalação existente
- Solicitar que você selecione uma pasta local no PC onde os jogos e mídias serão gerenciados (ex: `C:\PSBBN`).
- Iniciar o **[Menu Principal](#menu-principal)** do **PSBBN Definitive Project**

**Acessando o Menu Principal do PSBBN Definitive Project no Futuro:**  
Basta clicar com o botão direito em `PSBBN-Launcher-For-Windows.ps1` e selecionar **Executar com o PowerShell**

**NOTA:**  
É normal que a unidade selecionada seja desmontada no Windows durante a execução do script. Sempre saia do **[Menu Principal](#menu-principal)** do **PSBBN Definitive Project** pressionando a tecla `q`. Isso garante que a unidade seja desmontada com segurança do WSL e devolvida ao Windows. Para unidades USB, lembre-se também de ejetá-las pela bandeja do sistema do Windows antes de desconectá-las.

Se você tiver algum problema ao executar o **PSBBN Launcher for Windows**, consulte a aba de **[solução de problemas](#problemas-ao-executar-o-script)**.

## Menu Principal
Se esta for a primeira vez que você executa o script, ou se as dependências necessárias estiverem ausentes, o processo de configuração instalará automaticamente tudo o que for necessário antes que o menu principal seja exibido.

No menu principal, você terá as seguintes opções:

1. [Instalar PSBBN e HOSDMenu](#instalar-psbbn-e-hosdmenu) (Requer Adaptador de Rede oficial da Sony)  
Executa uma instalação limpa do [PSBBN](#psbbn) e do [HOSDMenu](#hosdmenu)

2. [Instalar apenas o HOSDMenu](#instalar-apenas-o-hosdmenu) (suporte a adaptadores de HDD de terceiros)
Executa uma instalação limpa do [HOSDMenu](#hosdmenu)

3. [Atualizar Software de Sistema do PS2](#atualizar-software-de-sistema-do-ps2)  
Atualiza uma instalação existente do [PSBBN](#psbbn) e do [HOSDMenu](#hosdmenu) para a versão mais recente

4. [Instalar Jogos e Aplicativos](#instalar-jogos-e-aplicativos)  
Instala jogos de PS1 e PS2, além de aplicativos homebrew.

5. [Instalar Mídia](#instalar-mídia)  
    1. [Instalar Música](#instalar-música)
    2. [Instalar Filmes](#instalar-filmes)
    3. [Instalar Fotos](#instalar-fotos)
    4. [Definir Local de Mídia](#definir-local-de-mídia)
    5. [Inicializar Partição de Música](#inicializar-partição-de-música)

6. [Extras Opcionais](#extras-opcionais)  
    1. [Instalar PS2 Linux](#instalar-ps2-linux)
    2. [Reatribuir Botões Cruz e Círculo](#reatribuir-botões-cruz-e-círculo) 
    3. [Mudar Idioma](#mudar-idioma)
    4. [Alterar Configurações de Tela](#alterar-configurações-de-tela)
    5. [Limpar Cache de Artes e Ícones](#limpar-cache-de-artes-e-ícones)

## Instalar PSBBN e HOSDMenu
Esta opção instala tanto o [PSBBN](#psbbn) quanto o [HOSDMenu](#hosdmenu). É necessário um Adaptador de Rede oficial da Sony[*](#problemas-conhecidos). O instalador executa as seguintes ações:
- Formata a unidade para uma instalação limpa
- Baixa o software de sistema mais recente do [PSBBN](#psbbn) e o pacote de idiomas do [archive.org](https://archive.org/)
- Instala o [PSBBN](#psbbn), [OSDMenu MBR](#osdmenu-mbr) e [HOSDMenu](#hosdmenu)
- Define o idioma da interface para corresponder ao do sistema operacional (assume o Inglês como padrão caso não esteja disponível)
- Se o idioma estiver definido como Japonês, baixa e instala os [Canais Online](#canal-de-internet) a partir do [archive.org](https://archive.org/)
- Solicita que você particione a unidade

Você tem **114 GB** disponíveis para partições APA. Será solicitado que você selecione um tamanho para as seguintes partições:
- Música (usada pelo [Canal de Música](#canal-de-música))
- Conteúdos (usada pelo [Canal de Filmes](#canal-de-filmes) e [Canal de Fotos](#canal-de-fotos))

Você pode, opcionalmente, reservar espaço na unidade para uso futuro. Este espaço é deixado não alocado e pode ser usado posteriormente para partições APA. Se você planeja instalar o PS2 Linux, reserve pelo menos 3 GB.

Uma partição exFAT é então criada usando o espaço restante do disco (até 2 TB) para armazenar jogos e aplicativos.

## Instalar apenas o HOSDMenu
Esta opção instala o [HOSDMenu](#hosdmenu) sem o [PSBBN](#psbbn) e é compatível com adaptadores de HDD de terceiros. O instalador executa as seguintes ações:
- Formata a unidade para uma instalação limpa
- Instala o [OSDMenu MBR](#osdmenu-mbr) e o [HOSDMenu](#hosdmenu)
- Define o idioma da interface para corresponder ao do sistema operacional (assume o Inglês como padrão caso não esteja disponível)
- Solicita que você particione a unidade

Você pode, opcionalmente, reservar espaço na unidade para uso futuro. Este espaço é deixado não alocado e pode ser usado posteriormente para partições APA. Até 50% da capacidade da unidade (máximo de 2 TB) pode ser reservado.

Uma partição exFAT é então criada usando o espaço restante do disco (até 2 TB) para armazenar jogos e aplicativos.

## Atualizar Software de Sistema do PS2
Selecionar esta opção verifica online as versões mais recentes do **Software de Sistema do PSBBN**, **Pacote de Idiomas**, [Canais Online](#canal-de-internet) e [OSDMenu](#hosdmenu), e então instala automaticamente quaisquer atualizações disponíveis. Todos os jogos, configurações e dados pessoais permanecem intactos.

## Instalar Jogos e Aplicativos
O **Instalador de Jogos** automatiza totalmente a instalação de jogos de PS1 e PS2, bem como de aplicativos homebrew:
- Detecta automaticamente a unidade do PS2
- Para usuários de Linux, permite definir um caminho personalizado no PC para armazenar jogos e aplicativos antes da instalação
- Oferece a escolha entre o [Open PS2 Loader (OPL)](#open-ps2-loader-opl) ou o [NHDDL](#nhddl) para o iniciador de jogos
- Atribui o iniciador de jogos escolhido, o [POPSLoader](#popsloader) e o [wLaunchELF-R3Z](#wlaunchelf-r3z) ao [botão de inicialização](#opções-de-inicialização)
- Instala quaisquer atualizações disponíveis para o [Open PS2 Loader (OPL)](#open-ps2-loader-opl), [NHDDL](#nhddl), [Neutrino](#nhddl), [POPSLoader](#popsloader), [wLaunchELF-R3Z](#wlaunchelf-r3z) e [R3CONFIGURATOR](#r3configurator)
- Baixa e instala os binários do [POPS](#popstarter) e instala o [POPStarter](#popstarter)
- Oferece a opção de aplicar uma correção HDTV para jogos de PS1, útil para usuários com uma TV que não suporta 240p
- Oferece a opção de [sincronizar](#sincronizar-todos-os-jogos-e-aplicativos) os jogos e aplicativos no PC com a unidade do PS2, ou de [adicionar](#adicionar-jogos-e-aplicativos-adicionais) jogos e aplicativos adicionais
- Converte automaticamente jogos de PS2 no formato `BIN/CUE` para `ISO` quando colocados na pasta `CD` do PC, e jogos de PS1 no formato `BIN/CUE` para `VCD` quando colocados na pasta `POPS` do PC
- Permite que você selecione quais jogos exibir na [Coleção de Jogos](#coleção-de-jogos) e na [Rotina de pesquisa](#hosdmenu)
- Para jogos no formato `ZSO`, o "Modo de Compatibilidade 1" é automaticamente ativado em suas configurações individuais do [OPL](#open-ps2-loader-opl)
- Cria [Memory Cards Virtuais (VMCs)](#memory-cards-virtuais) para todos os jogos de PS1, com a opção de ativar VMCs para todos os jogos de PS2. Também cria [Grupos VMC](#memory-cards-virtuais) para jogos que podem interagir com os dados de salvamento de outros jogos
- Configura jogos de PS1 de vários discos para permitir a troca de discos
- Baixa e instala automaticamente as [correções do HugoPocked POPStarter](https://www.psx-place.com/threads/hugopocked-fixes-for-popstarter.39750/), melhorando a compatibilidade de mais de 100 jogos de PS1
- Cria todos os recursos, incluindo metadados, artes e ícones para todos os jogos e aplicativos:
  - Baixa artes para a [Coleção de Jogos](#coleção-de-jogos) do PSBBN a partir do [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database) ou do IGN se não encontradas no banco de dados
  - Contribui automaticamente com as artes de jogos baixadas do IGN e relata artes ausentes para o [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database)
  - Baixa a arte da capa de jogos de PS2 e PS1 do [banco de dados de artes do OPL Manager](https://oplmanager.com/site/?backups) para exibição no [OPL](#open-ps2-loader-opl), [NHDDL](#nhddl) e [POPSLoader](#popsloader)
  - Baixa os ícones para a [Rotina de pesquisa](#hosdmenu) a partir do [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database). Se os ícones não estiverem disponíveis, mas houver imagens de um jogo no [Banco de Dados de Artes do OPL Manager](https://oplmanager.com/site/?backups), ícones 3D serão gerados automaticamente
  - Contribui automaticamente com ícones do HDD-OSD e relata ícones ausentes para o [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database)
- Atualiza atalhos para aplicativos homebrew no [Menu Navigator do PSBBN](#coleção-de-jogos) e no menu **OSDSYS** do [HOSDMenu](#hosdmenu)
- Cria **partições iniciadoras** que permitem que jogos e aplicativos selecionados instalados na unidade, junto com jogos de PS1 armazenados em um compartilhamento de rede SMB, sejam iniciados a partir da [Coleção de Jogos](#coleção-de-jogos) e da [Rotina de pesquisa](#hosdmenu)
- Ativa o BDM HDD, Apps e artes no arquivo de configuração do [OPL](#open-ps2-loader-opl)
- Define o idioma e a [configuração dos botões](#reatribuir-os-botoes-x-e-o) nos arquivos de configuração do [OPL](#open-ps2-loader-opl) e do [R3CONFIGURATOR](#r3configurator) para corresponderem às configurações de instalação

**NOTA:** Para usar arquivos `ZSO`, você deve selecionar o [OPL](#open-ps2-loader-opl) como iniciador de jogos. Ao usar o [NHDDL](#nhddl), quaisquer arquivos `ZSO` na pasta de jogos do PC ou na unidade do ps2 são descompactados em arquivos `ISO`.

### Sincronizar Todos os Jogos e Aplicativos
Esta opção atualiza o conteúdo do armazenamento do PS2 para corresponder ao conteúdo da pasta selecionada no PC. Quaisquer novos jogos ou aplicativos são copiados, e os que foram removidos do PC são excluídos do console.

O script permite definir um caminho personalizado no PC para armazenar os jogos a serem instalados. Basta colocar os arquivos na subpasta correta:
- Arquivos `ISO`, `ZSO` ou `BIN/CUE` de PS2 vão para a pasta `CD`
- Arquivos `ISO` ou `ZSO` de PS2 vão para a pasta `DVD`
- Arquivos `VCD` ou `BIN/CUE` de PS1 vão para a pasta `POPS`
- Arquivos `ELF` ou arquivos `PSU` [compatíveis com o SAS](#save-application-system-sas) vão para a pasta `APPS`

Para adicionar ou excluir jogos e aplicativos, basta modificar o conteúdo da pasta no PC e, em seguida, selecionar **Sincronizar Todos os Jogos e Aplicativos**.

### Adicionar Jogos e Aplicativos Adicionais
Alternativamente, você pode adicionar jogos e aplicativos homebrew diretamente no sistema de arquivos exFAT da unidade do PS2 colocando:
- Arquivos `ISO` ou `ZSO` de PS2 nas pastas `CD` ou `DVD`
- Arquivos `VCD` de PS1 na pasta `POPS`
- Arquivos `ELF` ou arquivos `PSU` [compatíveis com o SAS](#save-application-system-sas) na pasta `APPS`

Além disso, quaisquer novos jogos ou aplicativos encontrados na pasta selecionada no PC serão instalados. Assim como na sincronização, coloque:
- Arquivos `ISO`, `ZSO` ou `BIN/CUE` de PS2 vão para a pasta `CD`
- Arquivos `ISO` ou `ZSO` de PS2 vão para a pasta `DVD`
- Arquivos `VCD` ou `BIN/CUE` de PS1 vão para a pasta `POPS`
- Arquivos `ELF` ou arquivos `PSU` [compatíveis com o SAS](#save-application-system-sas) vão para a pasta `APPS`

Selecionar **Adicionar Jogos e Aplicativos Adicionais** baixa metadados e artes para todo o conteúdo recém-adicionado.

Jogos e aplicativos podem ser excluídos manualmente do sistema de arquivos exFAT da unidade do PS2. Selecionar **Adicionar Jogos e Aplicativos Adicionais** também removerá quaisquer títulos excluídos da [Coleção de Jogos](#coleção-de-jogos) e do [HOSDMenu](#hosdmenu).

### Seletor de Jogos
Ao executar o Instalador de Jogos, será apresentada uma lista de todos os títulos instalados, permitindo que você selecione quais títulos exibir na [Coleção de Jogos](#coleção-de-jogos) e no [Navegador](#hosdmenu). Se você tiver uma grande coleção, limitar o número de títulos exibidos pode melhorar sua experiência de navegação.

Até 800 títulos podem ser exibidos na [Coleção de Jogos](#coleção-de-jogos) e no [Navegador](#hosdmenu). Todos os jogos de PS2 permanecerão disponíveis no iniciador de jogos escolhido ([OPL](#open-ps2-loader-opl) ou [NHDDL](#nhddl)), e todos os jogos de PS1 permanecerão disponíveis no [POPSLoader](#popsloader).

Você também pode personalizar a ordem em que as categorias são exibidas, como Jogos de PS2, Jogos de PS1, Inicializadores e Aplicativos, para ter controle total sobre a organização da sua biblioteca.

### Instalando o ATA BDM Assault
Para iniciar jogos de PS1 pela Coleção de Jogos ou pela Rotina de pesquisa, você deve primeiro instalar os drivers ATA BDM Assault em um PS2 Memory Card.

1. Insira um PS2 Memory Card no seu console PS2.
2. Inicie o POPSLoader.
3. Inicie qualquer jogo de PS1.

Os drivers necessários serão instalados automaticamente no PS2 Memory Card.

### Iniciando Jogos de PS1 via SMB
Jogos de PS1 no formato `.VCD` armazenados em um compartilhamento de rede SMB podem ser iniciados a partir da [Coleção de Jogos](#coleção-de-jogos) e da [Rotina de pesquisa](#hosdmenu). Antes de executar o Instalador de Jogos:
1. Instale os jogos de PS1 e os arquivos de suporte necessários no dispositivo externo. Instruções podem ser encontradas [aqui](https://nathanneurotic.github.io/POPSTARTERINFO/smb-network.html)
2. Coloque os arquivos `POPSTARTER.ELF` renomeados com o prefixo `SB.` na pasta `POPS`, seja no PC ou diretamente na unidade do PS2.

### Save Application System (SAS)
O **Save Application System (SAS)** é um novo padrão para distribuição de aplicativos homebrew para o PS2. Todos os aplicativos compatíveis com o SAS são empacotados em um arquivo `PSU` e incluem ícones e metadados, sendo a maneira recomendada para [instalar aplicativos homebrew](#instalar-jogos-e-aplicativos) no [PSBBN](#psbbn) e no [HOSDMenu](#hosdmenu). Você pode baixar aplicativos compatíveis com o SAS na [PS2 Homebrew Store](https://ps2homebrewstore.com/).

## Instalar Mídia
**NOTA: Estes recursos são exclusivos para usuários do PSBBN.**  

Selecione **Install Media** no menu principal e você verá as seguintes opções:
1. [Instalar Música](#instalar-música)
2. [Instalar Filmes](#instalar-filmes)
3. [Instalar Fotos](#instalar-fotos)
4. [Definir Local de Mídia](#definir-local-de-mídia)
5. [Inicializar Partição de Música](#inicializar-partição-de-música)

### Instalar Música
Instale músicas para reprodução no [Canal de Música](#canal-de-música) do PSBBN. Para usar o Instalador de Música, você deve estar executando o **PSBBN Definitive Patch na versão 3.00 ou superior**. Se você atualizou de uma versão anterior, deve [Inicializar a Partição de Música](#inicializar-partição-de-música) primeiro.

Os formatos suportados são `.mp3`, `.m4a`, `.flac` e `.ogg`. Os metadados de cada arquivo devem incluir o título do álbum e o número da faixa. Coloque os arquivos de música na pasta padrão `music` no PC, ou escolha um local personalizado usando **[Definir Local de Mídia](#definir-local-de-mídia)** e coloque os arquivos na subpasta `music`.

### Instalar Filmes
Instale vídeos para reprodução no [Canal de Filmes](#canal-de-filmes) do PSBBN. Para usar o Instalador de Filmes, você deve estar executando o **PSBBN Definitive Patch na versão 3.00 ou superior**. O PC também deve ter um processador x86.

O Instalador de Filmes suporta `MP4`, `M4V`, `MKV`, `VOB` e outros formatos populares, bem como os formatos de vídeo do PlayStation 2 `pss` e `psm`. Vídeos curtos são codificados com uma taxa de bits maior que a de vídeos longos. Você deve limitar a duração dos vídeos a 2 horas e 15 minutos; vídeos mais longos podem resultar em uma codificação de baixa qualidade ou falhar durante a conversão.

Coloque os arquivos de vídeo na pasta padrão `movie` do PC, ou escolha um local personalizado usando **[Definir Local de Mídia](#definir-local-de-mídia)** e coloque os arquivos na subpasta `movie`.

### Instalar Fotos
Instale imagens para visualização no [Canal de Fotos](#canal-de-fotos) do PSBBN. Para usar o Instalador de Fotos, você deve estar executando o **PSBBN Definitive Patch na versão 3.00 ou superior**.

Os formatos suportados incluem `JPG`, `PNG`, `TIF`, `GIF`, `BMP` e outros formatos comuns. Coloque os arquivos de imagem na pasta padrão `photo` do PC, ou escolha um local personalizado usando o **[Definir Local de Mídia](#definir-local-de-mídia)** e coloque os arquivos na subpasta `photo`.

### Definir Local de Mídia
Configure um local personalizado para a pasta `media`. Músicas devem ser colocadas em uma subpasta `music`, vídeos em uma subpasta `movie`, e imagens em uma subpasta `photo`.

### Inicializar Partição de Música
Esta opção apaga todos os dados de música e reseta o banco de dados utilizado pelo [Canal de Música](#canal-de-música) do PSBBN. Use esta opção caso tenha atualizado a partir de uma versão do **PSBBN Definitive Patch** anterior à 3.0 e queira usar o [Instalador de Música](#instalar-música). Você também pode usar esta opção caso tenha problemas com o [Canal de Música](#canal-de-música).

## Extras Opcionais
Selecione **Extras Opcionais** no menu principal e você verá as seguintes opções:
1. [Instalar PS2 Linux](#instalar-ps2-linux)
2. [Reatribuir Botões Cruz e Círculo](#reatribuir-botões-cruz-e-círculo)
3. [Mudar Idioma](#mudar-idioma)
4. [Alterar Configurações de Tela](#alterar-configurações-de-tela)
5. [Limpar Cache de Artes e Ícones](#limpar-cache-de-artes-e-ícones)

### Instalar PS2 Linux
**NOTA: Este recurso é exclusivo para usuários do PSBBN.**  

O PlayStation 2 Linux é um kit oficial da Sony que transformava o PS2 em um computador pessoal baseado em Linux.  
A opção **Instalar PS2 Linux** permite que você instale ou reinstale o PS2 Linux.

Para usar este recurso, você deve:
- Reservar pelo menos 3 GB de espaço durante a [instalação do PSBBN](#instalar-psbbn-e-hosdmenu).
- Ter instalado o PSBBN Definitive Project versão 4.0.0 ou superior.

Ao reinstalar o PS2 Linux:
- Se o Linux já veio pré-instalado com a versão do PSBBN Definitive Project, todos os dados do PS2 Linux serão excluídos, incluindo o seu diretório home.
- Se você instalou ou reinstalou o Linux utilizando a opção **Instalar PS2 Linux**, apenas os arquivos do sistema serão reinstalados — os seus arquivos pessoais no diretório home não serão afetados.

Ao instalar o PS2 Linux pela primeira vez, ou ao reinstalar uma versão que veio pré-instalada com o PSBBN Definitive Project, você deverá escolher o tamanho do diretório home. O diretório home é onde ficam armazenados os seus arquivos pessoais e aplicativos.

**Notas:**  
- Para iniciar o PS2 Linux, ligue o console PS2 e segure o botão ○ no controle. O PS2 Linux será iniciado.  
- O PS2 Linux requer um teclado USB; o uso de um mouse é opcional, mas recomendado.  
- As contas de usuário `root` e `ps2` são ambas configuradas com a senha padrão `password`. 
- Para iniciar uma interface gráfica, digite `startx` na linha de comando.  
- Iniciar o navegador web **Dillo** abrirá um espelho (mirror) do antigo site oficial do PS2 Linux, onde você pode encontrar uma ampla variedade de softwares para baixar e testar.  

### Reatribuir Botões Cruz e Círculo
Esta opção permite que você inverta as funções dos botões × e ○ no controle. Você pode escolher entre o layout padrão (× = confirmar, ○ = voltar) ou o layout alternativo (○ = confirmar, × = voltar), dependendo da sua preferência.  

**NOTA: Este recurso se aplica apenas ao [PSBBN](#psbbn), [OPL](#open-ps2-loader-opl) e [R3CONFIGURATOR](#r3configurator). Ele não altera o layout dos botões na janela de **in-game reset** do [POPS](#popstarter) ao sair de um jogo de PS1, nem no [HOSDMenu](#hosdmenu).**  

### Mudar Idioma
Quando o [PSBBN](#psbbn) está instalado, esta opção altera o idioma do sistema do PSBBN. Selecione entre Inglês, alemão, Italiano, Português do Brasil, Espanhol, Francês e o Japonês original. Mais idiomas serão adicionados em futuras atualizações. Para usuários em Japonês, a ferramenta também baixa e instala as versões japonesas dos [Canais Online](#canal-de-internet).

Tanto para usuários do [PSBBN](#psbbn) quanto do [HOSDMenu](#hosdmenu), esta opção também altera o idioma da mensagem de **in-game reset** (IGR) do [POPS](#popstarter), do [OPL](#open-ps2-loader-opl), do [R3CONFIGURATOR](#r3configurator) e as preferências de idioma usadas pelo [Instalador de Jogos](#instalar-jogos-e-aplicativos).

Após alterar o idioma, é recomendável executar novamente o [Instalador de Jogos](#instalar-jogos-e-aplicativos) e selecionar *Adicionar Jogos e Aplicativos Adicionais* para atualizar os títulos dos jogos para o idioma selecionado (apenas para Inglês e Japonês). Para usuários do [PSBBN](#psbbn), isso também atualizará os manuais dos jogos de PlayStation.

### Alterar Configurações de Tela
**NOTA: Este recurso é exclusivo do PSBBN.**  
O [PSBBN](#psbbn) normalmente trava as configurações de tela do sistema em **4:3**. Esta opção permite alterar essa configuração. Você pode escolher entre **4:3**, **Cheia** e **16:9**.

Essa configuração é utilizada por alguns jogos e pelo [HOSDMenu](#hosdmenu). Ela não altera a proporção do próprio [PSBBN](#psbbn).

### Limpar Cache de Artes e Ícones
Esta opção remove todas as artes e ícones de jogos que estão armazenados localmente no PC. Na próxima vez que você executar o Instalador de Jogos, ele examinará a coleção de jogos e, em seguida, fará o download e aplicará novas cópias das artes e ícones necessários.  

Você pode querer limpar o cache se os jogos exibirem artes incorretas ou de baixa qualidade, já que artes atualizadas podem estar disponíveis.

# Guia do Usuário

## Opções de Inicialização
Você pode segurar determinados botões do controle enquanto liga o console PS2 para alterar como o sistema é inicializado:

| Botão | Software de Sistema do PS2 | Comportamento de Inicialização                                                               |
|-------|----------------------------|----------------------------------------------------------------------------------------------|
| Nenhum| PSBBN + HOSDMenu           | Inicializa automaticamente o [PSBBN](#psbbn)                                                 |
| Nenhum| Apenas HOSDMenu            | Inicializa automaticamente o [HOSDMenu](#hosdmenu)                                           |
| ✕     | PSBBN + HOSDMenu           | Inicializa o [HOSDMenu](#hosdmenu)                                                           |
| ○     | PSBBN + HOSDMenu           | Inicializa o [PS2 Linux](#instalar-ps2-linux) (se instalado)                                 |
| □     | Qualquer configuração      | Inicializa o iniciador de jogos selecionado ([OPL](#open-ps2-loader-opl) ou [NHDDL](#nhddl)) |
| △     | Qualquer configuração      | Inicializa o [POPSLoader](#popsloader)                                                       |
| START | Qualquer configuração      | Inicializa o [wLaunchELF-R3Z](#wlaunchelf-r3z)                                               |

## PSBBN
O PlayStation Broadband Navigator (também conhecido como BB Navigator e PSBBN) é um sistema operacional oficial do PlayStation 2 lançado exclusivamente no Japão. Ele possui canais para [jogos](#coleção-de-jogos), [música](#canal-de-música), [filmes](#canal-de-filmes), [fotos](#canal-de-fotos) e [serviços de internet](#canal-de-internet).

O **Definitive Patch** aprimora e expande suas funcionalidades, oferecendo:
- Uma tradução completa do software BB Navigator Japonês original (versão 0.32) — Todos os binários, arquivos XML, texturas e imagens foram traduzidos[*](#problemas-conhecidos)
- Disponibilidade em Inglês, alemão, Italiano, Português do Brasil, Espanhol, Francês e no Japonês original
- Suporte para consoles PS2 de todas as regiões; o software original era restrito a consoles japoneses
- [OSDMenu MBR](#osdmenu-mbr) — um substituto homebrew para o programa MBR original da Sony, com inúmeras melhorias em relação à implementação original
- Um `osdboot.elf` corrigido (patched) para contornar a verificação de segurança CRC, permitindo o uso de kernels personalizados
- Suporte para HDDs de grande capacidade — originalmente limitado a 128 GB. Unidades de até 2 TB agora são suportadas usando o [APA-Jail](#apa-jail)
- Uma partição de música de até 114 GB para cerca de 180 álbuns[*](#problemas-conhecidos); originalmente limitada a 5 GB
- Uma partição de conteúdos de até 114 GB para o armazenamento de filmes e fotos; originalmente limitada a 5 GB
- Um link direto para a [Coleção de Jogos](#coleção-de-jogos) no **Menu Principal** (Top Menu) para acesso rápido
- Verificações de autorização DNAS burladas para permitir o acesso aos [canais online](#canal-de-internet)
- [Canais online](#canal-de-internet) da Sony, Hudson, EA, Konami, Capcom, Namco, KOEI, Bandai, So-Net e BIGLOBE
- [Canais online](#canal-de-internet) japoneses originais em Japonês nas instalações japonesas e em Inglês em todas as outras instalações
- O recurso **Audio Player** foi readicionado ao [Canal de Música](#canal-de-música) a partir de uma versão anterior do PSBBN, permitindo compatibilidade com gravadores MiniDisc NetMD[*](#problemas-conhecidos)
- Manuais e páginas de solução de problemas sobre o recurso **Audio Player** foram readicionados ao guia do usuário
- Teclado virtual QWERTY Japonês substituído por um teclado virtual em Inglês (EUA)[*](#problemas-conhecidos)
- Uma opção para trocar as funções dos botões × e ○
- Uma opção para alterar as configurações de tela (normalmente travada em 4:3), com modos selecionáveis: 4:3, Cheia e 16:9.
- Suporte para o controle remoto de DVD do PlayStation 2[*](#problemas-conhecidos)

Para ver os detalhes completos de todos os recursos e um guia completo do usuário, consulte o **Guia do PlayStation BB**, acessível pelo **Menu Principal**.

### Coleção de Jogos
Você pode encontrar a **Coleção de Jogos** no **Menu Principal** (Top Menu) do PSBBN. Este é o primeiro menu que você vê quando o PSBBN é iniciado.
- Quando instalados pelo [Instalador de Jogos](#instalar-jogos-e-aplicativos), todos os aplicativos e [jogos selecionados](#seletor-de-jogos) serão exibidos na coleção em uma interface estilo 'cover flow'.
- Os itens são agrupados em jogos de PS2, jogos de PS1 e aplicativos homebrew.
- Jogos de PS2 e PS1 são classificados em ordem alfabética e organizados por franquia (série), com os jogos de uma mesma série ordenados por data de lançamento.
- Quando o idioma está definido como Japonês, os títulos de jogos da região Japonesa são exibidos em Japonês e classificados na ordem 'gojūon' (五十音).
- Os aplicativos homebrew são classificados em ordem alfabética, enquanto os [aplicativos SAS](#save-application-system-sas) são divididos em subgrupos com base no tipo de aplicativo (sistema, jogo, emulador, etc.).  
- Você pode visualizar um manual para jogos de PS1 que lista as teclas de atalho suportadas. Para acessar o manual, pressione **△** sobre um jogo de PS1 destacado e selecione *Manual*.
- Você pode definir atalhos para até quatro itens pressionando **△** sobre um jogo destacado e selecionando *Adicionar ao Menu Navigator*. Você pode acessar rapidamente os atalhos pressionando **SELECT**.

### Canal de Música
O **Canal de Música** permite que você reproduza CDs de áudio, ouça músicas armazenadas na unidade interna do PS2 e crie playlists personalizadas. Músicas podem ser extraídas diretamente no PS2 a partir de um CD de áudio, e instaladas usando o [Instalador de Música](#instalar-música).

Ele também suporta a exportação de músicas para um gravador de MiniDisc compatível com NetMD. No entanto, o suporte a MiniDisc está quebrado na versão atual do PSBBN Definitive Patch. Se você quiser testar a funcionalidade do MiniDisc, pode usar uma [versão antiga do PSBBN Definitive English Patch](https://github.com/CosmicScale/PSBBN-Definitive-Project/tree/PSBBN-Definitive-English-Patch).

### Canal de Filmes
O **Canal de Filmes** permite que você reproduza filmes armazenados na unidade interna do PS2, organize os filmes e crie playlists. Os filmes podem ser baixados a partir de vários [Canais Online](#canal-de-internet), e instalados usando o [Instalador de Filmes](#instalar-filmes).

### Canal de Fotos
O Canal de Fotos permite que você visualize fotos armazenadas na unidade interna do PS2 ou em um dispositivo USB formatado em FAT (pendrive, câmera digital, etc.). Fotos podem ser importadas de dispositivos USB e instaladas usando o [Instalador de Fotos](#instalar-fotos). Você pode criar álbuns e playlists com as suas fotos. Você também pode baixar artes de jogos e capturas de tela a partir dos [Canais Online](#canal-de-internet).

### Canal de Internet
No **Canal de Internet**, você pode acessar arquivos de canais online de várias produtoras, exatamente como apareciam no início dos anos 2000. Os canais foram traduzidos para o Inglês (trabalho em andamento). Se você tiver uma instalação japonesa do PSBBN, terá acesso às versões originais em Japonês. Para visualizar esses canais online, o sistema PlayStation 2 deve estar conectado à internet. No **Canal de Internet** você pode:
- Explorar os canais online de várias produtoras de jogos, incluindo Sony, Hudson, EA, Konami, Capcom, Namco, KOEI e Bandai.
- Baixar trailers de *Metal Gear Solid 3: Subsistence*, *Bomberman Online* e mais. Os trailers podem ser baixados a partir do **Canal Konami**, **BANDAI Entertainment World** e do **CANAL HUDSON**. Os trailers baixados são salvos em um álbum no [Canal de Filmes](#canal-de-filmes).
- Baixar artes e capturas de tela do canal **PlayStation® Now!**. As imagens baixadas são salvas em um álbum no [Canal de Fotos](#canal-de-fotos).
- Jogar uma série de jogos clássicos do arquivo da Hudson, incluindo *Star Soldier*, *Milon’s Secret Castle* e *Nuts & Milk*. Os jogos podem ser jogados selecionando *PLAY GAMES* no menu principal do **CANAL HUDSON**.

## HOSDMenu
O **HDD-OSD** é um software oficial da Sony que expande o menu de sistema do PlayStation 2 (OSDSYS) com suporte a disco rígido, permitindo que você gerencie softwares, dados salvos e inicie jogos e aplicativos diretamente do HDD através do Browser 2.0. O **HOSDMenu**, escrito por [pcm720](https://github.com/pcm720), aplica correções (patches) no **HDD-OSD** e adiciona recursos extras, incluindo:
- Suporte a unidades maiores — o **HDD-OSD** era anteriormente limitado a 1 TB
- Iniciar aplicativos homebrew diretamente do menu personalizado do **OSDSYS**
- Iniciar [aplicativos compatíveis com o SAS](#save-application-system-sas) a partir de Memory Cards e da unidade interna no **Browser 2.0**
- Suporte para inicializar aplicativos a partir de MMCE, MX4SIO, UDPBD, dispositivos iLink e HDDs formatados em APA e exFAT
- Iniciar [Discos de Jogos de PS1 e PS2](#iniciando-discos-de-jogos-de-ps1-e-ps2) com suporte a ID do Jogo, MechaPwn e PS1VmodeNeg integrado
- GSM integrado para jogos em disco e aplicativos
- Suporte a resoluções de 1080i e 480p
- E mais — veja o [repositório no GitHub](https://github.com/pcm720/OSDMenu) para detalhes completos

Se instalado junto com o [PSBBN](#psbbn), ele pode ser iniciado a partir da [Coleção de Jogos](#coleção-de-jogos), por meio de um [atalho no Menu Navigator](#coleção-de-jogos), ou segurando o botão × enquanto o console liga. Se apenas o **HOSDMenu** foi instalado, ele inicializará automaticamente.

Quando instalado através do [Instalador de Jogos](#instalar-jogos-e-aplicativos):
- Os aplicativos aparecerão no menu do **OSDSYS**, permitindo uma inicialização rápida
- Os [jogos selecionados](#seletor-de-jogos) aparecerão no **Navegador** (Browser) como ícones 3D exclusivos, modelados com base na caixa física do jogo em DVD/CD, provenientes do [HDD-OSD Icon Database](https://github.com/CosmicScale/HDD-OSD-Icon-Database)
- Os [aplicativos compatíveis com o SAS](#save-application-system-sas) baixados na [PS2 Homebrew Store](https://ps2homebrewstore.com/) também aparecerão no **Navegador** representados por ícones exclusivos.

## Open PS2 Loader (OPL)
O [Open PS2 Loader (OPL)](https://github.com/ps2homebrew/Open-PS2-Loader) é um carregador de jogos e aplicativos 100% de código aberto para o PS2. Todos os jogos de PS2 instalados serão exibidos no OPL. Se você selecionar o OPL como o iniciador de jogos ao [instalar jogos e aplicativos](#instalar-jogos-e-aplicativos), as configurações por jogo (per-game settings) atribuídas no OPL serão refletidas ao iniciar os jogos a partir da [Coleção de Jogos](#coleção-de-jogos) e da [Rotina de pesquisa](#hosdmenu).

## NHDDL
O [NHDDL](https://github.com/pcm720/nhddl) é um iniciador para o [Neutrino](https://github.com/rickgaiser/neutrino), um emulador de dispositivo de PS2 pequeno, rápido e modular. Todos os jogos de PS2 instalados serão exibidos no NHDDL. Se você selecionar o NHDDL como o iniciador de jogos ao [instalar jogos e aplicativos](#instalar-jogos-e-aplicativos), as configurações por jogo (per-game settings) atribuídas no NHDDL serão refletidas ao iniciar os jogos a partir da [Coleção de Jogos](#coleção-de-jogos) e da [Rotina de pesquisa](#hosdmenu).

## POPSLoader
O [POPSLoader](https://github.com/NathanNeurotic/POPSLoader) é um iniciador gráfico desenvolvido para facilitar a navegação e a inicialização de jogos de PS1 (usando o [POPStarter](#popstarter)) a partir de vários dispositivos de armazenamento. Todos os jogos de PS1 instalados serão exibidos no **POPSLoader**.

## POPStarter
O **POPS** é um emulador oficial de PS1 da Sony para o PS2, lançado originalmente com exclusividade no Japão como uma forma de distribuir jogos de PS1 pela internet para os usuários do [PSBBN](#psbbn). O **POPStarter** é um iniciador homebrew para o **POPS** que permite ao emulador reproduzir qualquer jogo de PS1 a partir de unidades internas e externas.

Ao instalar jogos de PS1, as **[correções do HugoPocked POPStarter](https://www.psx-place.com/threads/hugopocked-fixes-for-popstarter.39750/)** são automaticamente baixadas e instaladas, melhorando a compatibilidade de mais de 100 jogos de PS1.

Combinações de botões de atalho são suportadas para a troca de discos e várias outras opções:

| Atalho                 | Função                                |
|------------------------|---------------------------------------|
| SELECT + START + L1    | Sair do jogo                          |
| SELECT + L2 + R2 + ✕  | Reiniciar software                    |
| SELECT + L1 + R2 	     | Ativar mapeamento de textura suave    |
| SELECT + L2 + R1       | Desativar mapeamento de textura suave |
| SELECT + R1 + R2       | Ativar scanlines                      |
| SELECT + L1 + L2       | Desativar scanlines                   |
| SELECT + L2 + R2 + △  | Abrir tampa de CD do PlayStation      |
| SELECT + L2 + R2 + ↑   | Inserir disco 1                       |
| SELECT + L2 + R2 + →   | Inserir disco 2                       |
| SELECT + L2 + R2 + ↓   | Inserir disco 3                       |
| SELECT + L2 + R2 + ←   | Inserir disco 4                       |
| SELECT + L2 + R2 + □   | Fechar tampa de CD do PlayStation     |

Os detalhes sobre os atalhos também podem ser encontrados no **Manual** de cada jogo de PS1 instalado. Para acessá-lo, na **[Coleção de Jogos](#coleção-de-jogos)**, pressione **△** e, em seguida, selecione **Manual**.

## Saindo dos Jogos
Combinações de botões de atalho são suportadas para sair dos jogos e desligar o console.

**NOTA: Se você selecionou o [NHDDL](#nhddl) como iniciador de jogos, não poderá executar essas funções enquanto joga títulos de PS2.**

| Atalho                             | Função                                 |
|------------------------------------|----------------------------------------|
| SELECT + START + L1 	             | Sair de Jogos de PS1                   |
| L1 + L2 + R1 + R2 + SELECT + START | Sair de Jogos de PS2                   |
| L1 + L2 + L3 + R1 + R2 + R3        | Desligar Console (Apenas Jogos de PS2) |

## Memory Cards Virtuais
Um **Memory Card Virtual (VMC)** permite que você armazene o progresso dos jogos na unidade interna do PlayStation 2 em vez de em um Memory Card padrão.

Um **POPStarter VMC** é criado para cada jogo de PS1 e, ao executar o [Instalador de Jogos](#instalar-jogos-e-aplicativos), você terá a opção de ativar **VMCs** para todos os jogos de PS2.

Tanto os jogos de PS1 quanto os de PS2 suportam **Grupos VMC**, permitindo que determinados jogos compartilhem um VMC e acessem dados salvos criados por outros títulos. Por exemplo, o Psycho Mantis de *Metal Gear Solid* pode comentar sobre outros jogos da Konami que você jogou, e os créditos de *Gran Turismo 3* podem ser transferidos para o *Gran Turismo 4*.

## ID do Jogo
O recurso ID do Jogo no **Retro GEM**, **MemCard Pro 2** e **SD2PSX** é totalmente suportado ao iniciar jogos e aplicativos homebrew a partir da [Coleção de Jogos](#coleção-de-jogos) e da [Rotina de pesquisa](#hosdmenu), bem como de discos físicos de jogos de PS1 e PS2.

O **Retro GEM** é uma modificação de saída HDMI digital-para-digital para diversos consoles. O **Retro GEM ID do Jogo** permite a troca automática de perfis de exibição com base em cada jogo. Você pode saber mais sobre o **Retro GEM** no [site da Pixel FX](https://www.pixelfx.co/hdmi-retro-gem).

O **MemCard Pro 2** e o **SD2PSX** permitem que os dados salvos (saves) sejam armazenados em um cartão SD, suportando múltiplos **Memory Cards Virtuais (VMCs)** e muitos outros recursos. O **ID do Jogo** identifica qual jogo está rodando, permitindo que cada jogo tenha o seu próprio **VMC** atribuído, e alterna automaticamente para o cartão correto quando o jogo é iniciado. Você pode saber mais sobre o **MemCard Pro 2** no [site da 8BitMods](https://8bitmods.com/accessories/memcard-pro/) e sobre o **SD2PSX** no [site do SD2PSX](https://sd2psx.net/).

## Iniciando Discos de Jogos de PS1 e PS2
Ao executar o [PSBBN](#psbbn) ou o [HOSDMenu](#hosdmenu), basta inserir um disco de jogo na unidade de DVD. O jogo será inicializado e definirá o [ID do Jogo](#id-do-jogo) adequadamente, tanto no **Retro GEM** quanto no **MemCard Pro** ou **SD2PSX**.

O [MechaPwn](https://github.com/MechaResearch/MechaPwn) também é totalmente suportado, com correção automática (patching) do logotipo do PS2 que permite iniciar discos importados e discos master sem pular o logotipo do PlayStation 2 ou se deparar com uma tela corrompida. Ao reproduzir jogos importados de PS1, o modo de vídeo do driver do PlayStation é ajustado, se necessário, para garantir que eles rodem no modo de vídeo correto.

## wLaunchELF-R3Z
Uma variação (fork) do [wLaunchELF](https://github.com/ps2homebrew/wLaunchELF) criada por [R3Z3N](https://github.com/saildot4k) que inclui vários recursos avançados. Notavelmente, ele permite que você gerencie arquivos na partição exFAT da unidade interna, uma capacidade não disponível em outras forks do wLaunchELF. Mais informações estão disponíveis [aqui](https://github.com/saildot4k/wLaunchELF_R3Z).

## R3CONFIGURATOR
Um aplicativo com interface gráfica (GUI) para editar o [OSDMenu](osdmenu-mbr) e outros arquivos de configuração. Ele permite modificar opções de inicialização (como atribuir um aplicativo a um botão para inicialização rápida), definir os modos de exibição do [HOSDMenu](#hosdmenu), ativar ou desativar o menu personalizado **OSDSYS** do [HOSDMenu](#hosdmenu), e muito mais.

Você pode encontrar todos os detalhes na [página do R3CONFIGURATOR no GitHub](https://github.com/saildot4k/R3CONFIGURATOR).

## OSDMenu MBR
O **OSDMenu MBR** é um componente central do **PSBBN Definitive Project**. Escrito por [pcm720](https://github.com/pcm720), este programa é executado a cada inicialização do sistema e sempre que um aplicativo é iniciado a partir do [PSBBN](#psbbn). Ele é um substituto homebrew para o programa MBR original da Sony, sendo o responsável por inicializar o hardware, bem como executar aplicativos e discos de jogos.

O **OSDMenu MBR** possui muitas vantagens em relação à implementação original, incluindo o suporte para inicializar arquivos ELF segurando um botão do controle durante a inicialização, correção automática (patching) do logotipo do PS2 ao [iniciar discos de jogos de PS2](#iniciando-discos-de-jogos-de-ps1-e-ps2), ajuste dos modos de vídeo ao [iniciar discos importados de PS1](#iniciando-discos-de-jogos-de-ps1-e-ps2), [Visual ID do Jogo](#id-do-jogo) para o **Retro GEM**, modificação das configurações do sistema e execução de aplicativos homebrew e jogos via [OPL](#open-ps2-loader-opl), [NHDDL](#nhddl) e [POPStarter](#popstarter).

O arquivo **readme** completo pode ser encontrado [aqui](https://github.com/pcm720/OSDMenu/blob/main/mbr/README.md).

## APA-Jail
![APA-Jail Type-A2](https://github.com/user-attachments/assets/8c83dab7-f49f-4a77-b641-9f63d92c85e7)

O **APA-Jail** é outro componente central do **PSBBN Definitive Project**. O [PSBBN](#psbbn) era originalmente limitado a apenas 128 GB de armazenamento útil. O **APA-Jail** possibilita ultrapassar pouco mais de 2 TB.  

O **APA-Jail**, criado e desenvolvido por [Berion](https://www.psx-place.com/resources/authors/berion.1431/), permite que as partições APA do PS2 coexistam com uma partição exFAT. Para o [PSBBN](#psbbn), até 128 GB da unidade podem ser reservados para partições APA, enquanto o espaço restante (até 2 TB) é formatado em exFAT. Essa configuração permite que o [PSBBN](#psbbn) e o [HOSDMenu](#hosdmenu) sejam instalados nas partições APA, enquanto os jogos e aplicativos homebrew são instalados na partição exFAT.

O [OSDMenu MBR](#osdmenu-mbr) reside em uma partição APA especial. Quando um item é selecionado na [Coleção de Jogos](#coleção-de-jogos), o [OSDMenu MBR](#osdmenu-mbr) carrega os jogos e os aplicativos homebrew a partir da partição exFAT. Jogos de PS1 são executados via [POPStarter](#popstarter) e os de PS2 via [OPL](#open-ps2-loader-opl) ou [NHDDL](#nhddl).

**Aviso: Criar manualmente novas partições APA na unidade do ps2 excedendo o espaço alocado para o sistema APA corromperá a unidade.**

## Consoles Antigos (SCPH-10000–18000) e Slim (SCPH-700xx)
O **PSBBN Definitive Project** pode ser instalado nos modelos PS2 Slim **SCPH-700xx** usando um [IDE Resurrector](https://gusse.in/shop/ps2-modding-parts/ide-resurrector-origami-v0-7-flex-cable-for-ps2-slim-spch700xx/) ou mod de hardware semelhante. A instalação em um cartão SD não é suportada no Windows. Para garantir a compatibilidade com o PSBBN, é obrigatório utilizar um adaptador SATA, como o [iFlash-Sata v10](https://www.iflash.xyz/store/iflash-sata-v10/).

Você também deve baixar os [Drivers de HDD Externo](https://israpps.github.io/FreeMcBoot-Installer/test/8_Downloads.html). Extraia os arquivos e coloque `hddload.irx`, `dev9.irx` e `atad.irx` na pasta de sistema correspondente à região dentro de um **Memory Card oficial de PS2 da Sony**:

| Região   | Nome da Pasta |
|----------|-------------- |
| Japonês  | BIEXEC-SYSTEM |
| Americano| BAEXEC-SYSTEM |
| Asiático | BAEXEC-SYSTEM |
| Europeu  | BEEXEC-SYSTEM |
| Chinês   | BCEXEC-SYSTEM |

Os modelos **SCPH-10000 a SCPH-18000** que possuem o case oficial de HDD externo não possuem a capacidade de inicialização automática sem o uso de um software adicional. Para iniciar o PSBBN, é recomendado usar o **PlayStation 2 Basic Boot Loader (PS2BBL)**. [Instale o PS2BBL como uma atualização de sistema](https://israpps.github.io/PlayStation2-Basic-BootLoader/Downloads/) no Memory Card do PS2. No arquivo de configuração (`config`), defina a linha `LK_AUTO_E1` apontando para `hdd0:/__system/p2lboot/osdboot.elf`.

# Solução de Problemas
⚠️ **Problema conhecido**: A instalação no **Fedora** é atualmente problemática. Recomenda-se usar uma distribuição **baseada em Debian** ou o próprio **[PSBBN Launcher for Windows](#instalando-no-windows)**.

1. Certifique-se de que está usando a versão mais recente do sistema operacional e que todas as atualizações disponíveis estão instaladas.
2. Use um Sistema Operacional recomendado. O **PSBBN Definitive Project** foi totalmente testado no:
- Debian
- Linux Mint
- Raspberry Pi OS
- Windows 10 Home Edition
- Windows 11 Home Edition

## Problemas ao Executar o Script

**Se você receber o erro "Falha ao criar a lista de jogos":**

O arquivo `ISO`, `ZSO` ou `VCD` que está sendo processado provavelmente é inválido ou está corrompido. Remova o arquivo tanto da pasta local no PC quanto da unidade do PS2 e tente novamente.

Para evitar este problema, certifique-se de que a imagem do jogo é um "dump" (cópia) verificado e válido. Verifique o checksum MD5 ou SHA-1 do arquivo `ISO` ou `BIN` e confirme se ele corresponde à entrada respectiva no [redump.org](http://redump.org).

**Se você estiver usando o [Windows](#instalando-no-windows) e tiver problemas:**

Se o [menu do PSBBN Definitive Project](#menu-principal) exibir quadrados em vez de texto, ou se o [menu do Seletor de Jogos](#seletor-de-jogos) não for renderizado corretamente, altere a fonte do PowerShell. Clique com o botão direito na barra de título do PowerShell, abra as **Propriedades** e selecione **Cascadia Mono** (Windows 11) ou **MS Gothic** (Windows 10).

Para outros problemas, siga as etapas de solução de problemas abaixo:

1. Abra o PowerShell como administrador e execute o seguinte comando:
```
wsl --unregister PSBBN
```
2. Baixe a versão mais recente do script `PSBBN-Launcher-For-Windows.ps1` [aqui](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/releases/download/latest/PSBBN-Launcher-For-Windows.ps1)
3. Certifique-se de ter uma conexão de internet ativa. Se estiver usando uma VPN, tente desativá-la.
4. Execute o script `PSBBN-Launcher-For-Windows.ps1` novamente.

**Se você estiver usando o [Linux](#instalando-no-linux) e encontrar problemas:**
1. Exclua a pasta `PSBBN-Definitive-Project`.
2. Clone novamente o repositório executando o seguinte comando:
```
git clone https://github.com/CosmicScale/PSBBN-Definitive-Project.git
```

**Ainda está com problemas?**
1. Tente conectar a unidade do PS2 diretamente ao PC usando uma conexão SATA interna ou uma porta USB diretamente na placa-mãe. Evite usar placas complementares (placas de expansão).
2. Se você estiver usando um adaptador SATA para USB, tente usar uma marca ou modelo diferente.
3. Se você ainda tiver problemas, tente usar uma unidade (drive) diferente.

## Problemas ao Iniciar o PSBBN e o HOSDMenu
Quando você conectar a unidade no console PS2 e ligá-lo, o **[PSBBN ou o HOSDMenu](#opções-de-inicialização)** deve inicializar automaticamente.

Se o console inicializar na tela clássica do PS2 (OSD regular), travar/congelar ou exibir um erro, tente o seguinte:
1. Remova todos os Memory Cards de PS2 do console.
2. Se você instalou o [PSBBN](#psbbn), certifique-se de estar usando um **Adaptador de Rede oficial da Sony**; o PSBBN não suporta adaptadores de HDD de terceiros.
3. Verifique se os conectores do console e do adaptador de rede/HDD estão limpos, isentos de poeira e sem detritos.
4. Certifique-se de que a unidade e o adaptador de rede/HDD estão firmemente conectados de forma segura ao console.
5. Se estiver usando uma placa com Mod SATA, certifique-se de que ela foi instalada corretamente.
6. Use uma unidade diferente e reinstale o [PSBBN](#instalar-psbbn-e-hosdmenu) ou o [HOSDMenu](#instalar-apenas-o-hosdmenu).
7. Se o console possui um conversor IDE ou um Mod SATA instalado, tente usar outro conversor ou outro mod.
8. Use um outro Adaptador de Rede oficial da Sony ou outro adaptador de HDD de terceiros.
9. Use um console PS2 diferente.

## Jogos Não Funcionam
Alguns jogos podem falhar ao executar ou apresentar problemas de compatibilidade. Primeiro, certifique-se de que a imagem do jogo é um "dump" (cópia) verificado e válido. Verifique o checksum MD5 ou SHA-1 do arquivo `ISO` ou `BIN` e confirme se ele corresponde à respectiva entrada no [redump.org](http://redump.org).

Se você tiver problemas ao iniciar jogos de PS1, certifique-se de ter instalado corretamente os **drivers do ATA BDM Assault** em um Memory Card de PS2 e de que ele esteja inserido no console. As instruções de instalação estão disponíveis [aqui](#instalando-o-ata-bdm-assault).

Para problemas com jogos de PS2, se você selecionou o [OPL](#open-ps2-loader-opl) como launcher de jogos, você pode verificar os problemas existentes ou relatar um novo [aqui](https://github.com/ps2homebrew/Open-PS2-Loader/issues). Se você selecionou o [NHDDL](#nhddl), você pode fazer isso [aqui](https://github.com/rickgaiser/neutrino/issues).

Se todos os jogos de PS1 ou PS2 falharem ao iniciar, siga as etapas abaixo:

Se os jogos falharem ao iniciar a partir da [Coleção de Jogos](#coleção-de-jogos) ou da [Rotina de pesquisa](#hosdmenu), tente o seguinte:
1. Se o console possui um [Mod Chip](#problemas-conhecidos), desative-o.
2. Se estiver tendo problemas para iniciar jogos de PS2, remova todos os Memory Cards de PS2 do console e tente novamente. Se isso resolver o problema, exclua quaisquer arquivos de salvamento com o nome `Your System Configuration` dos memory cards, pois dados de configuração corrompidos podem impedir que os jogos iniciem.
3. Verifique se os conectores do console e do Adaptador de Rede/HDD estão limpos, isentos de poeira e sem detritos.
4. Certifique-se de que a unidade e o Adaptador de Rede/HDD estão firmemente conectados de forma segura ao console.
5. Se estiver usando uma placa com Mod SATA, certifique-se de que ela foi instalada corretamente.

Se ainda assim os jogos não iniciarem, tente carregar os jogos de PS2 usando o [OPL](#open-ps2-loader-opl) ou o [NHDDL](#nhddl), e os jogos de PS1 usando o [POPSLoader](#popsloader).

Se o OPL travar/congelar na inicialização, exclua quaisquer arquivos de configuração do OPL que existam nos Memory Cards do PS2 ou em dispositivos USB conectados. Você também pode segurar o botão `START` enquanto o OPL inicia para ignorar a leitura do arquivo de configuração.

Para exibir a lista de jogos no OPL, ajuste as seguintes configurações:
1. Configurações > Modo de Início no HDD: DESLIGADO
2. Configurações > Modo de Início no BDM: Automático
3. Configurações > Configurações de Dispositivos > HDD (GPT/MBR): LIGADO
4. Configurações > Salvar Mudanças

Se os jogos de PS2 não aparecerem na lista de jogos do [NHDDL](#nhddl) ou do [OPL](#open-ps2-loader-opl) (após modificar as configurações do OPL conforme descrito acima), ou se os jogos de PS1 não aparecerem no [POPSLoader](#popsloader), tente o seguinte:
1. Conecte a unidade do PS2 diretamente ao PC usando uma conexão SATA interna ou um adaptador SATA para USB diferente, e então reinstale o [PSBBN](#instalar-psbbn-e-hosdmenu) ou o [HOSDMenu](#instalar-apenas-o-hosdmenu).
2. Use uma unidade (drive) diferente e reinstale o [PSBBN](#instalar-psbbn-e-hosdmenu) ou o [HOSDMenu](#instalar-apenas-o-hosdmenu).
3. Se o console possui um conversor IDE ou um Mod SATA instalado, tente usar outro conversor ou outro mod.
4. Use um outro Adaptador de Rede oficial da Sony ou outro adaptador de HDD de terceiros.
5. Use um console PS2 diferente.

## Relatando Problemas
Se você já tentou os passos relevantes acima e o problema persistir, verifique se já existe algum relato sobre o erro ou abra um novo [aqui](https://github.com/CosmicScale/PSBBN-Definitive-Project/issues).  
Por favor, inclua todos os arquivos de log relevantes:
- `setup.log`
- `PSBBN-installer.log`
- `hosdmenu.log`
- `game-installer.log`
- `extras.log`
- `media.log`

Usuários de **Linux** podem encontrar esses arquivos de log em `PSBBN-Definitive-Project/logs`. Usuários de **Windows** podem encontrar esses arquivos de log na pasta onde os jogos e arquivos de mídia estão armazenados.

# Problemas Conhecidos
- O PSBBN travará no logotipo "PlayStation 2" ao iniciar se um adaptador de HDD não oficial de terceiros for usado. **Um Adaptador de Rede oficial da Sony é obrigatório**.
- O PSBBN travará ao iniciar jogos ou aplicativos se um modchip estiver ativo. Para usar o PSBBN, os modchips devem ser desativados.  
- Há casos no feega em que algum texto em Japonês não pôde ser traduzido pelo fato de estar inserido diretamente (hard-coded) em um arquivo criptografado. O software Atok não foi traduzido.  
- O suporte para MiniDisc parou de funcionar a partir da versão 2.10 do patch e superiores. Espero corrigir isso em uma futura atualização.  
- O teclado virtual padrão do PSBBN está configurado para Japonês. No entanto, um teclado virtual em Inglês (EUA) foi adicionado, embora você precise pressionar o botão `SELECT` várias vezes para alternar para ele. Há um bug onde a barra de espaço não funciona no teclado virtual em Inglês, mas você pode inserir um espaço pressionando o botão **△** no controle como alternativa.  
- No PSBBN, a inversão das funções dos botões × e ○ só é suportada em controles DualShock 2.
- No PSBBN, os botões de mídia do Controle Remoto de DVD do PS2 só são suportados em consoles SCPH-5000x com receptor IR (infravermelho) embutido. O controle remoto pode se comportar de forma errática se não houver um controle conectado na Porta 1.
- As músicas instaladas com o Instalador de Música só podem ser reproduzidas se forem gravadas nos primeiros 3 GB da partição de música. Músicas extraídas de CDs de áudio no [Canal de Música](#canal-de-música) não são afetadas e podem usar a capacidade total da partição.
- O PSBBN suporta datas apenas até o final de 2030. Ao configurar a hora e a data, o ano deve ser definido como 2030 ou inferior.
- Instalações japonesas do PSBBN falharão em unidades menores que 128 GB.
- A partição exFAT não pode exceder 2 TB. Ao usar uma unidade maior, o espaço restante além desse limite ficará inutilizável.
- O **wLaunchELF** e outros aplicativos nativos do PS2 não conseguem criar partições APA na unidade do PS2. Novas partições devem ser criadas apenas usando a versão do **PFS Shell** incluída neste projeto.
- Partições APA não devem ser criadas além do espaço reservado para a configuração APA durante a instalação. Fazer isso sobrescreverá os dados na partição exFAT.

# Créditos
**PSBBN Definitive Project - Copyright © 2024-2026 por [CosmicScale](https://github.com/CosmicScale)**
- `PSBBN-Definitive-Patch.sh`, `Setup.sh`, `PSBBN-Installer.sh`, `HOSDMenu-Installer.sh`, `Game-Installer.sh`, `Media-Installer.sh`, `music-installer.py`, `psmbuild.py`, `Extras.sh`, `art_downloader.py`, `list-builder.py`, `list-sorter.py`, `txt_to_icon_sys.py`, `ps2iconmaker.sh`, `AppDB.csv`, `TitlesDB_PS1.csv`, `TitlesDB_PS2.csv`, `ps1_vmc_groups.list`, `POP-game-fixes.list`, `game-selector.py` escritos por [CosmicScale](https://github.com/CosmicScale)
- `game-selector.py` baseado em um script escrito por [Luiz Antonio Lazoti](https://github.com/luizoti)
- `PSBBN-Launcher-For-Windows.ps1` escrito por Yornn
- `icon_sys_to_txt.py` escrito por [NathanNeurotic (Ripto)](https://github.com/NathanNeurotic)
- Ícone 3D do PSBBN criado por Yornn
- Usa código do APA-Jail oriundo do [PS2 HDD Decryption Helper](https://www.psx-place.com/resources/ps2-hdd-decryption-helper.1507/) feito por [Berion](https://www.psx-place.com/members/berion.1431/)
- Contém código do [`list_builder.py`](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin/blob/main/List%20Builder/list_builder.py) proveniente do [XEB+ neutrino Launcher Plugin](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin) feito por [sync-on-luma](https://github.com/sync-on-luma)
- Contém código de [`ps2iconmaker.sh`](https://github.com/CosmicScale/HDD-OSD-Icon-Database/issues/1#issuecomment-2852499188) feito por [Sakitoshi](https://github.com/Sakitoshi)
- Contém dados de [`TitlesDB_PS1_English.txt`](https://github.com/GDX-X/PFS-BatchKit-Manager/blob/main/PFS-BatchKit-Manager/BAT/TitlesDB/TitlesDB_PS1_English.txt) e [`TitlesDB_PS2_English.txt`](https://github.com/GDX-X/PFS-BatchKit-Manager/blob/main/PFS-BatchKit-Manager/BAT/TitlesDB/TitlesDB_PS2_English.txt) do [PFS-BatchKit-Manager](https://github.com/GDX-X/PFS-BatchKit-Manager) fornecidos por [GDX-X](https://github.com/GDX-X)
- Contém dados de [`vmc_groups.list`](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin/blob/main/List%20Builder/vmc_groups.list) do [XEB+ neutrino Launcher Plugin](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin) feitos por [sync-on-luma](https://github.com/sync-on-luma)
- Equipe de Localização do PSBBN
  - Inglês — [CosmicScale](https://github.com/CosmicScale)
  - Alemão — [Argo707](https://github.com/Argo707)
  - Italiano — [plamadika](https://github.com/plamadika) & [lcipria](https://github.com/lcipria)
  - Português do Brasil — [Emerson Teles (Emertels)](https://github.com/Emertels)
  - Espanhol — [Ignacio Trillo (Nacheras)](https://github.com/Nacheras) & [ViZoRRetrogames](https://github.com/ViZoRRetrogames)
  - Francês — [Bistroww](https://github.com/Bistroww) & [iSlickick](https://github.com/iSlickick)

**O PSBBN Definitive Project usa as seguintes ferramentas e aplicativos homebrew de PS2:**
- [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database) criado e mantido por [CosmicScale](https://github.com/CosmicScale)
- [HDD-OSD Icon Database](https://github.com/CosmicScale/HDD-OSD-Icon-Database) criado e mantido por [CosmicScale](https://github.com/CosmicScale)
- [OSDMenu](https://github.com/pcm720/OSDMenu) de [pcm720](https://github.com/pcm720)
- [APA Partition Header Checksumer](https://github.com/pink1stools/APA-Partition-Header-Checksumer/) feito por [Pink1](https://github.com/pink1stools) e [Berion](https://www.psx-place.com/members/berion.1431/). [Port para Linux](https://github.com/bucanero/save-decrypters/tree/master/ps2-apa-header-checksum) por [Bucanero](https://github.com/Bucanero)
- [PFS Shell](https://github.com/AKuHAK/pfsshell/tree/ext2) e [HDL Dump](https://github.com/AKuHAK/hdl-dump/tree/8M) com modificações para partições APA de 8MB e EXT2 feitas por [AKuHAK](https://github.com/AKuHAK)
- PFS Fuse a partir do [PFS Shell](https://github.com/ps2homebrew/pfsshell) feito por [PS2 Homebrew Projects](https://github.com/ps2homebrew)
- PSU Extractor a partir do [PSV Save Converter](https://github.com/bucanero/psv-save-converter) por [Bucanero](https://github.com/Bucanero)
- [`ziso.py`](https://github.com/ps2homebrew/Open-PS2-Loader/blob/master/pc/ziso.py) feito por Virtuous Flame
- cue2pops oriundo do [pops2cue](https://github.com/bucanero/pops2cue) de [Bucanero](https://github.com/Bucanero)
- [Open PS2 Loader](https://github.com/ps2homebrew/Open-PS2-Loader) mantido por [PS2 Homebrew Projects](https://github.com/ps2homebrew) com contribuições focadas em BDM de [KrahJohlito](https://github.com/KrahJohlito) e modificações no Auto Launch criadas por [CosmicScale](https://github.com/CosmicScale)
- [Neutrino](https://github.com/rickgaiser/neutrino) de [Rick Gaiser](https://github.com/rickgaiser)
- [NHDDL](https://github.com/pcm720/nhddl) de [pcm720](https://github.com/pcm720)
- [POPStarter](https://www.psx-place.com/resources/popstarter.683/) de [KrHACKen](https://www.psx-place.com/members/krhacken.98/)
- [POPSLoader](https://github.com/NathanNeurotic/POPSLoader) feito por [NathanNeurotic (Ripto)](https://github.com/NathanNeurotic)
- [Correções do HugoPocked POPStarter](https://www.psx-place.com/threads/hugopocked-fixes-for-popstarter.39750/) feitas por [HugoPocked](https://ko-fi.com/hugopocked)
- [ATA BDM Assault](https://github.com/saildot4k/ATA-Assault) de [R3Z3N](https://github.com/saildot4k)
- [wLaunchELF_R3Z](https://github.com/saildot4k/wLaunchELF_R3Z) de [R3Z3N](https://github.com/saildot4k)
- [R3CONFIGURATOR](https://github.com/saildot4k/R3CONFIGURATOR) de [R3Z3N](https://github.com/saildot4k)
- Artes de capa de PS2 retiradas dos [backups do Banco de Artes do OPL Manager](https://oplmanager.com/site/index.php?backups)
- Artes de aplicativos retiradas do [OPL B-APPS Cover Pack](https://www.psx-place.com/resources/opl-b-apps-cover-pack.1440/) e [OPL Discs & Boxes Pack](https://www.psx-place.com/resources/opl-discs-boxes-pack.1439/) como cortesia de [Berion](https://www.psx-place.com/resources/authors/berion.1431/)
- Canais online hospedados e traduzidos para o Inglês por vitas155 no [psbbn.ru](https://psbbn.ru/), com exceção do PlayStation Now! e do Canal Konami, traduzidos para o Inglês por [CosmicScale](https://github.com/CosmicScale)

**Bibliotecas e Binários de Terceiros:**  
- `vmlinux` **Kernel do BB Navigator (Linux 2.4.17)** – Código fonte disponível [aqui](https://github.com/CosmicScale/PSBBN-Definitive-Patch-Kernel)
- **SQLite v2.8.17** do [sqlite.org](https://www.sqlite.org) 
- **mkfs.exfat (exfatprogs 1.2.2)** do [exfatprogs](https://github.com/exfatprogs/exfatprogs)
- `binmerge.py` do [binmerge](https://github.com/putnam/binmerge)

**Todas as bibliotecas e utilitários possuem código aberto e são utilizados em conformidade com as suas respectivas licenças.**

**Agradecimentos:**
- [Bucanero](https://github.com/Bucanero) por compilar os binários ARM64
- A todos da [Equipe SAS/UMCS](https://ps2homebrewstore.com/thanks/) pelo seu trabalho contínuo na [PS2 Homebrew Store](https://ps2homebrewstore.com/)
- Um agradecimento especial a [pcm720](https://github.com/pcm720) por aplicar o patch no `osdboot.elf` que contorna a verificação de segurança CRC
