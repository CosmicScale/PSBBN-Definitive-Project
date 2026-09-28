# PSBBN Definitive Project

| [English](https://github.com/CosmicScale/PSBBN-Definitive-Project/blob/main/README.md) | [Português (Brasil)](https://github.com/CosmicScale/PSBBN-Definitive-Project/blob/main/README-PT-BR.md) | **Español** |

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://github.com/CosmicScale/PSBBN-Definitive-Project/blob/main/LICENSE)  
Este es el Proyecto Definitivo del software "PlayStation Broadband Navigator" de Sony (también conocido como BB Navigator o PSBBN) para la consola de videojuegos "PlayStation 2" (PS2).

PSBBN es el software oficial de Sony para PlayStation 2, lanzado exclusivamente en Japón. Introducido en 2002 como reemplazo del OSD de la PS2, requería tanto un disco duro como un adaptador de red para funcionar. Agregó muchas características nuevas:
- Iniciar juegos desde el disco duro
- Acceder a canales en línea
- Descargar juegos completos, demostraciones, videos e imágenes
- Copiar CD de audio y transferir música a grabadoras MiniDisc en el Canal de Música
- Ver videos en el Canal de Películas
- Transferir fotos desde una cámara digital y verlas en el Canal de Fotos

El **PSBBN Definitive Project** (anteriormente el parche definitivo en inglés PSBBN) comenzó en 2023 como un parche en inglés para PSBBN, pero se expandió constantemente mucho más allá de su alcance original. Este proyecto ahora admite varios idiomas y tiene como objetivo proporcionar la configuración definitiva para el disco interno de PlayStation 2.

Puede obtener más información sobre el software PSBBN original en [Wikipedia](https://en.wikipedia.org/wiki/PlayStation_Broadband_Navigator) y seguir el desarrollo de este proyecto en mi [canal de YouTube](https://www.youtube.com/@CosmicScaleFactor).

# Donaciones
Si aprecias mi trabajo y quieres apoyar el desarrollo continuo de **PSBBN Definitive Project** y otros proyectos relacionados con PS2, [puedes hacer una donación a mi Ko-fi](https://ko-fi.com/cosmicscale).

Este proyecto utiliza [Webhook.site](https://webhook.site/) para contribuir e informar automáticamente obras de arte e íconos faltantes a la [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database) y [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database). A medida que el proyecto ha ganado popularidad, estamos excediendo el límite ofrecido por una cuenta gratuita. Una suscripción paga cuesta $9/mes o $90/año, las donaciones también ayudan a financiar esto.

# Demostración en Video de PSBBN

[![PSBBN en 2024](https://github.com/user-attachments/assets/298c8c0b-5726-4485-840d-9d567498fd95)](https://www.youtube.com/watch?v=kR1MVcAkW5M)

# Características
Hay dos opciones de instalación:
- [PSBBN y HOSDMenu](#instale-psbbn-y-hosdmenu): requiere un adaptador de red oficial de Sony[*](#problemas-conocidos)
- [Solo HOSDMenu](#instalar-hosdmenu-únicamente): admite adaptadores de red oficiales de Sony y adaptadores HDD de terceros

Ambas opciones de instalación ofrecen:
- [Instaladores](#instale-psbbn-y-hosdmenu) que facilitan la configuración
- Compatibilidad con unidades más grandes con [APA-Jail](#apa-jail): un esquema de partición híbrido permite que un sistema de archivos exFAT y un sistema de archivos PlayStation (PFS) coexistan en la misma unidad.
- Sistema de archivos exFAT usado para almacenamiento y administración sencilla de juegos y aplicaciones caseras
- Sistema de archivos PFS usado para software del sistema y soporte heredado
- [HOSDMenu](#hosdmenu): una versión parcheada del software HDD-OSD de Sony que ofrece [muchas ventajas](#hosdmenu) sobre FreeHDBoot
- Vea, explore e inicie sus juegos y aplicaciones directamente desde el [Navegador](#hosdmenu), representado por [iconos 3D](https://github.com/CosmicScale/HDD-OSD-Icon-Database)
- Compatibilidad con [Game ID](#id-del-juego) para **Pixel FX Retro GEM**, **MemCard Pro** y **SD2PSX**: funciona con juegos y aplicaciones instalados, así como con discos físicos de juegos.
- [MechaPwn](#lanzamiento-de-discos-de-juegos-de-ps1-y-ps2) admite parches automáticos del logotipo de PS2, lo que permite iniciar importaciones y discos de respaldo. También ajusta el modo de vídeo del controlador de PlayStation para discos de juegos de PS1 importados.
- Incluye las aplicaciones [wLaunchELF-R3Z](#lanzamientoelf-r3z), [R3CONFIGURATOR](#configurador-r3) y [POPSLoader](#cargador-de-cop), con la opción de [OPL](#open-ps2-loader-opl) o [NHDDL](#nhddl) para el iniciador de tu juego.
- Un [Instalador de Juegos y Aplicaciones](#instalar-juegos-y-aplicaciones) que automatiza completamente la instalación de juegos de PS1 y PS2, así como de aplicaciones caseras:
  - Crea recursos y descarga ilustraciones e íconos para todos tus juegos y aplicaciones
  - Ofrece una opción para instalar hacks de pantalla panorámica para juegos de PS2 que permiten la compatibilidad con pantalla panorámica 16:9 en juegos compatibles.
  - Ofrece una opción para crear [Tarjetas de Memoria Virtuales](#tarjetas-de-memoria-virtuales) (VMC) para juegos de PS2, con soporte para [Grupos de VMC](#tarjetas-de-memoria-virtuales) para juegos de PS1 y PS2.
  - Configura juegos de PS1 multidisco para permitir el intercambio de discos
  - Instala automáticamente [correcciones de HugoPocked POPSarter](#iniciador-pop)
  - Convierte archivos `.bin`/`.cue` a `.VCD` (PS1) o `.ISO` (PS2)
  - Ofrece la opción de comprimir archivos `ISO`
  - Configura los ajustes de compatibilidad OPL para juegos
  - Agrega aplicaciones instaladas al menú del sistema [HOSDMenu](#hosdmenu)

**Exclusivo para Instalaciones PSBBN:**
- **PSBBN Definitive Patch** — una versión mejorada del software [PSBBN](#psbbn) de Sony que ofrece [muchas ventajas](#psbbn) sobre la versión estándar
- Vea, explore e inicie sus juegos y aplicaciones directamente desde la [Colección de juegos](#colección-de-juegos) con una interfaz estilo cover-flow
- [Canal de música](#canal-de-música) para reproducción de música y extracción de CD. Utilice el [Instalador de música](#instalar-música) para instalar archivos de música desde su PC (`.mp3`, `.m4a`, `.flac`, `.ogg`)
- [Canal de película](#canal-de-peliculas) para reproducción de vídeo. Descargue videos de los [canales en línea](#canal-de-internet), o use el [Instalador de películas](#instalar-películas) para instalar archivos de video desde su PC (`.mp4,` `.m4v`, `.mkv`, `.vob`, `.pss`, `.psm` y otros formatos populares)
- [Canal de fotos](#canal-de-fotos) para ver imágenes. Importe imágenes desde unidades USB o cámaras digitales, o instálelas desde su PC usando [Photo Installer](#instalar-fotos) (`.jpg`, `.png`, `.tif`, `.gif`, `.bmp` y otros formatos comunes)
- [Canal de Internet](#canal-de-internet) que ofrece acceso a réplicas de los canales originales de juegos en línea de varios editores, lo que le permite descargar avances y capturas de pantalla de juegos, y jugar juegos retro clásicos.
- [Extras opcionales](#extras-opcionales) como instalar [PS2 Linux](#instalar-ps2-linux)

# Registro de Cambios

**17 de Septiembre de 2026: Juegos Comprimidos, Trucos de Pantalla Ancha, Instalador Homebrew Mejorado**
<p><p>

[![Actualización PSBBN: Compresión de Juegos, Trucos de Pantalla Ancha, Instalador Homebrew Mejorado y Más.](https://github.com/user-attachments/assets/4dfe26c8-7349-4f14-97d1-e88e616ea599)](https://youtu.be/ImmUr69x57Y)

**Nuevas Características:**

**[Instalador de Juegos y Aplicaciones](#instalar-juegos-y-aplicaciones):**
- Se agregó una opción para comprimir archivos `ISO` de PS2 al instalar juegos. Habilite esta opción para ahorrar espacio y colocar más juegos en su disco.
- Se agregó una opción para instalar hacks de pantalla panorámica para juegos de PS2, lo que permite una verdadera compatibilidad con pantalla panorámica 16:9 con un campo de visión más amplio en juegos compatibles.
- Se mejoró el instalador de aplicaciones caseras. La base de datos de aplicaciones se ha ampliado para contener detalles de más de 500 aplicaciones, incluido su título, desarrollador, ID del título y categoría.
- El [Selector de juegos](#selector-de-juegos) ahora divide las aplicaciones caseras en las siguientes categorías: emuladores, juegos, demostraciones, aplicaciones, aplicaciones de PS1, aplicaciones de sistema, herramientas de diagnóstico, aplicaciones de depuración y entornos de ejecución. Puede reorganizar libremente las categorías según sus preferencias.
- Se han agregado más de 500 íconos del navegador para aplicaciones a [HDD-OSD Icon Database](https://github.com/CosmicScale/HDD-OSD-Icon-Database). El instalador ahora descarga estos íconos para mostrarlos en el [Navegador de HOSDMenu](#hosdmenu).
- Las aplicaciones en el [Navegador](#hosdmenu) ahora muestran la categoría a la que pertenecen.
- [R3CONFIGURATOR](#configurador-r3) ahora está asignado a una [clave de inicio](#opciones-de-arranque) y se puede iniciar en el inicio manteniendo presionado el botón *SELECT*.

**[Extras Opcionales](#extras-opcionales):**
- Los usuarios exclusivos de HOSDMenu ahora pueden usar la opción [Reasignar botones en cruz y círculo](#reassign-X-and-Círculo-buttons) en el [menú Extras opcionales](#extras-opcionales). Esto intercambia las funciones de los botones × y ○ en [OPL](#open-ps2-loader-opl), [wLaunchELF-R3Z](#lanzamientoelf-r3z) y [R3CONFIGURATOR](#configurador-r3).

**Mejoras y Correcciones de Errores:**
- Títulos mejorados generados automáticamente para aplicaciones `ELF` cuando no se encuentra ninguna coincidencia en la base de datos.
- Las aplicaciones con archivos `title.cfg` faltantes o con formato incorrecto ahora están instaladas correctamente
- Se agregó clasificación natural para aplicaciones con acentos en sus títulos usando `list-sorter.py`.
- Detección de números romanos mejorada en `list-sorter.py`
- Se eliminaron las etiquetas de categorías y se enumeran las aplicaciones alfabéticamente en el [menú OSDSYS] (#hosdmenu).
- Se movió la creación de recursos de la aplicación después de que se ejecuta el selector de juegos, lo que evita la creación de recursos innecesarios.
- Se corrigió la detección de errores para fallas en [selector de juegos](#selector-de-juegos).
- Se corrigió el intercambio de botones para [R3CONFIGURATOR](#configurador-r3).
- Comprobaciones mejoradas para [wLaunchELF-R3Z](#lanzamientoelf-r3z) y [R3CONFIGURATOR](#configurador-r3) antes de crear accesos directos a ellos.
- Solo elimine las aplicaciones existentes asignadas a la clave de inicio *START* si [wLaunchELF-R3Z](#lanzamientoelf-r3z) está instalado.
- Se eliminó el paso de copia del kernel innecesario al cambiar de idioma.
- Sólo monte `__linux.9` cuando el idioma se cambie a japonés.
- Se agregó ruso a la selección de idioma en preparación para la próxima localización al ruso.
- El instalador ahora envía una lista de todos los archivos `ELF` instalados y sus carpetas principales al registro.
- Se corrigió la variable de idioma enviada al registro.
- Se corrigió el mensaje de la interfaz de usuario "Procesando archivos ELF".
- Se eliminaron los scripts redundantes `txt_to_icon_sys.py` y `icon_sys_to_txt.py` y sus comprobaciones asociadas.

<details>
<summary>13 de agosto de 2026: localización húngara, paquetes de idiomas, actualizaciones de R3CONFIGURATOR y wLaunchELF_R3Z</summary>

- El PSBBN Definitive Project ahora se ha traducido completamente al húngaro. Puede cambiar el idioma de su instalación PSBBN desde el menú Extras opcionales.
- Todos los paquetes de idiomas se han actualizado con correcciones y traducciones mejoradas.
- R3CONFIGURATOR se actualizó a [v1.3.1](https://github.com/saildot4k/R3CONFIGURATOR/releases/tag/v1.3.1) y wLaunchELF_R3Z se actualizó a [v4.76](https://github.com/saildot4k/wLaunchELF_R3Z/releases/tag/v4.76). Para actualizarlos, seleccione "Instalar juegos y aplicaciones" en Menú Principal.
</details>

<details>
<summary>29 de julio de 2026: Selector de Juegos v2, OSDMenu 1.3.0 y más.</summary>
<p><p>

[![Actualización PSBBN: Selector de Juegos V2, OSDMenu 1.3.0 y Más.](https://github.com/user-attachments/assets/4395d7ec-7af4-4954-8e30-7b562c5cef3d)](https://youtu.be/UEsqDorgbew)

**[Selector de Juegos:](#selector-de-juegos)**
- Administre todos sus juegos y aplicaciones con [Selector de Juegos](#selector-de-juegos) v2.
- Seleccione qué títulos aparecen en la [Colección de juegos](#colección-de-juegos) y el [Navegador](#hosdmenu).
- Personalice el orden en que aparecen las categorías, como Juegos de PS2, Juegos de PS1, Iniciadores y Aplicaciones, lo que le brinda control total sobre cómo está organizada su biblioteca.

**Menú OSD:**
- [OSDMenu MBR](#osdmenu-mbr) y [HOSDMenu](#hosdmenu) actualizados a [v1.3.0](#https://github.com/pcm720/OSDMenu/releases/tag/v1.3.0).
- Se redujo el tiempo de inicio de [PSBBN](#psbbn).
- Se agregó soporte para [claves de inicio del gamepad] adicionales (#opciones-de-arranque). Ahora se admiten todas las claves excepto `L3` y `R3`.
- [R3CONFIGURADOR](#configurador-r3) actualizado a [v1.3.0](https://github.com/saildot4k/R3CONFIGURATOR/releases/tag/v1.3.0).

**Otros Cambios:**
- [POPSLoader](#cargador-de-cop) actualizado a la última versión continua
- [Instalación del controlador ATA BDM Assault](#instalaãão-dos-drivers-ata-bdm-assault) más sencilla con [POPSLoader](#cargador-de-cop)
- [wLaunchELF_R3Z](#lanzamientoelf-r3z) actualizado a [v4.75](#https://github.com/saildot4k/wLaunchELF_R3Z/releases/tag/v4.75)
- La configuración de idioma para [wLaunchELF_R3Z](#lanzamientoelf-r3z) y [POPSLoader](#cargador-de-cop) ahora se configura automáticamente.
- La configuración de [Configuración del botón](#reassign-X-and-Círculo-buttons) para [wLaunchELF_R3Z](#lanzamientoelf-r3z) ahora se establece automáticamente.
- Se agregó una traducción al portugués brasileño de [PSBBN Definitive Project README](https://github.com/CosmicScale/PSBBN-Definitive-Project/blob/main/README-PT-BR.md).
- Varias correcciones de errores y limpieza de código.
</details>

<details>
<summary>02 de julio de 2026: localización mejorada, selector de juegos, PS1 en exFAT, POPSLoader, wLaunchELF-R3Z y R3CONFIGURATOR</summary>
<p><p>

[![¡Localización Mejorada, Selector de Juegos, PS1 en ExFAT, POPSLoader y Más!](https://github.com/user-attachments/assets/c1828dbf-e1ba-4c67-8ae0-ccff79f4a524)](https://youtu.be/Bqf8XCfa0QM)  

**Nuevas Características:**
- Ahora se muestra un registro de cambios antes de [Menú Principal](#menú-principal) cada vez que se publica una nueva actualización.
- Los scripts **PSBBN Definitive Project** se han traducido completamente al inglés, japonés, francés, español, alemán, italiano y portugués de Brasil. El idioma de su sistema operativo se detecta automáticamente y el proyecto se ejecuta en ese idioma, siendo el inglés de forma predeterminada si no está disponible. Los usuarios de **Windows** deberán actualizar a la última versión de **[PSBBN Launcher for Windows](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/releases/download/latest/PSBBN-Launcher-For-Windows.ps1)** para que esta función funcione.
- El [Instalador de juegos](#instalar-juegos-y-aplicaciones) ahora cuenta con un [Selector de juegos](#selector-de-juegos), que le permite seleccionar qué juegos mostrar en la [Colección de juegos](#colección-de-juegos) y el [Navegador](#hosdmenu). Si tiene una colección grande, limitar la cantidad de juegos mostrados puede mejorar su experiencia de navegación.
- Los juegos de PS1 ahora se instalan en la partición exFAT junto con los juegos y aplicaciones de PS2, eliminando las limitaciones de espacio causadas por APA. Los juegos previamente instalados permanecerán en la partición `POPS` y seguirán siendo reproducibles. Para jugar juegos de PS1 desde la partición exFAT, **DEBE** instalar los [controladores ATA BDM Assault](#instalaãão-dos-drivers-ata-bdm-assault) en una tarjeta de memoria de PS2.
- Los juegos de PS1 almacenados en un [recurso compartido de red SMB](#lanzamiento-de-juegos-de-ps1-desde-smb) ahora se pueden iniciar desde la [Colección de juegos](#colección-de-juegos) y el [Navegador](#hosdmenu). Coloque un `POPSTARTER.ELF` renombrado con el prefijo `SB.` en la carpeta `POPS` y luego ejecute el [Instalador del juego](#instalar-juegos-y-aplicaciones).
- Se ha agregado la aplicación [POPSLoader](#cargador-de-cop). Esto te permite navegar y cargar fácilmente juegos de PS1. [POPSLoader](#cargador-de-cop) se puede iniciar desde la [Colección de juegos](#colección-de-juegos) o Menu Navigator, el [HOSDMenu](#hosdmenu) Navegador o menú del sistema, y ​​manteniendo presionado [△](#opciones-de-arranque) en el arranque.
- Se agregó la integración de [POPSLoader](#cargador-de-cop) al [Instalador de juegos](#instalar-juegos-y-aplicaciones), las ilustraciones del juego se descargan automáticamente para todos tus juegos de PS1.
- **wLaunchELF-ISR** ha sido reemplazado por [wLaunchELF-R3Z](#lanzamientoelf-r3z), agregando soporte para administrar archivos en la partición exFAT del disco interno. Ahora se puede iniciar en el arranque manteniendo presionado el botón [START](#opciones-de-arranque).
- **OSDMenu Configurator** ha sido reemplazado por [R3CONFIGURATOR](#configurador-r3), agregando soporte multilingüe.

**Mejoras:**
- [Instalador PSBBN y HOSDMenu](#instale-psbbn-y-hosdmenu) y [Instalador exclusivo HOSDMenu](#instalar-hosdmenu-únicamente):
  - Ya no crea una partición `POPS`, lo que permite particiones de música y contenidos más grandes o una partición exFAT más grande.
  - Se ha eliminado la selección de idioma. Ahora se instala automáticamente en el mismo idioma que su sistema operativo y, de forma predeterminada, se instala en inglés si ese idioma no está disponible.
- [Instalador exclusivo de HOSDMenu](#instalar-hosdmenu-únicamente):
  - Le permite reservar espacio para futuras particiones APA. Se puede reservar hasta el 50% de la capacidad del disco (máximo 2 TB).
- [Instalador del juego](#instalar-juegos-y-aplicaciones):
  - La configuración de idioma y botones ahora se establece automáticamente en [OPL](#open-ps2-loader-opl) y [R3CONFIGURATOR](#configurador-r3) para que coincida con la configuración de instalación.
  - Los juegos de PS2 ahora se muestran primero en la [Colección de juegos](#colección-de-juegos) y el [Navegador](#hosdmenu), seguidos de los juegos de PS1 y las aplicaciones caseras.
  - La salida del [Game Installer](#instalar-juegos-y-aplicaciones) se ha optimizado y ahora incluye barras de progreso.
  - Ahora tienes la opción de desactivar [PS2 VMC](#tarjetas-de-memoria-virtuales) si estaban activados anteriormente.
  - El espacio disponible ahora se muestra en MB, GB o TB según el tamaño.
  - El arte de OPL ahora se guarda directamente en la unidad PS2.
  - Se agregaron instrucciones para los usuarios de **Linux** sobre dónde colocar los archivos compatibles, reflejando [PSBBN Launcher for Windows](#instalación-en-windows).
- Todos los archivos de registro ahora se truncan cuando superan los 4 MB.
- El número de confirmación actual **PSBBN Definitive Project** se registra en los archivos de registro.
- Se agregó un enlace a la [guía de solución de problemas](#solución-de-problemas) a todos los mensajes de error.
- README actualizado, reestructurado y mejorado.

**Corrección de Errores:**
- Se impide que el script se ejecute en modo no interactivo.
- [OPL](#open-ps2-loader-opl) se actualizó a v1.2.0-Beta-2245-3e3f34e, solucionando un problema de lectura de configuración al inicio que algunos usuarios estaban experimentando.
- El [Instalador de música](#instalar-música) ahora admite el manejo de caracteres internacionales.
- El [Instalador del juego](#instalar-juegos-y-aplicaciones) ahora omite los archivos ocultos, evitando que se instalen.
- Se evita que los archivos `.ZSO` duplicados se descompriman cuando los archivos `.ZSO` están presentes y [NHDDL](#nhddl) está seleccionado como iniciador del juego.
- Muestra una advertencia si falta un archivo `.bin` al convertir a `.iso`. Omite la conversión de `.VCD` si falta el archivo `.bin`
- Comprobaciones mejoradas para la creación exitosa de las listas de juegos.
- Maneja correctamente las ID de juegos duplicadas incluso cuando los archivos están en carpetas diferentes.
- Se corrigió el truncamiento incorrecto de títulos de juegos japoneses en el [Navegador](#hosdmenu).
- El montaje de `__linux.9` ahora se omite para instalaciones no japonesas, lo que permite la compatibilidad con unidades más pequeñas.
</details>

<details>
<summary>16 de abril de 2026: compatibilidad mejorada con PS1, VMC de PS2, actualización de OPL y más.</summary>
<p><p>

[![¡Compatibilidad Mejorada Con PS1, VMC de PS2, Actualización de OPL y Más!](https://github.com/user-attachments/assets/1dc75789-bbd4-45df-9615-7e9bd8bd3ac5)](https://youtu.be/oRm3QIwdf1o)  

- **[OPL](#open-ps2-loader-opl)** actualizado a **v1.2.0 Beta-2241-39afed2**: soluciona problemas de lectura de configuración en la partición exFAT de la unidad interna
- **[NHDDL](#nhddl)** actualizado a **[v1.2.2](https://github.com/pcm720/nhddl/releases/tag/v1.2.2)**
- **[Neutrino](#nhddl)** actualizado a **[v1.8.0](https://github.com/rickgaiser/neutrino/releases/tag/v1.8.0)**: reduce el tiempo de inicio del juego en unos 4 segundos
- **[OSDMenu](#osdmenu-mbr)** actualizado a **v1.2.1**: soluciona problemas con los argumentos de inicio al iniciar ELF mediante el botón del gamepad al inicio

**[Instalador del Juego](#instalar-juegos-y-aplicaciones):**
- Asigna el iniciador del juego elegido ([OPL](#open-ps2-loader-opl) o [NHDDL](#nhddl)) al botón □, lo que permite que se inicie rápidamente al inicio.
- Crea un archivo de configuración **[OPL](#open-ps2-loader-opl)** en su unidad. BDM HDD, aplicaciones y obras de arte ahora se habilitan automáticamente
- Los juegos en formato `ZSO` ahora tienen el "Modo de compatibilidad 1" habilitado automáticamente en sus configuraciones **[OPL](#open-ps2-loader-opl)** por juego.
- Ahora se pueden instalar varios juegos que comparten el mismo ID de título, lo que permite la instalación de una variedad de modificaciones.
- Los juegos de PS1 ahora cuentan con un nuevo borde estilo PSN en PSBBN **[Colección de juegos](#colección-de-juegos)**, lo que facilita la distinción entre juegos de PS1 y PS2.
- Instalación automática de **[correcciones de HugoPocked POPSarter](https://www.psx-place.com/threads/hugopocked-fixes-for-popstarter.39750/)**, mejorando la compatibilidad con más de 100 juegos de PS1.

**Corrección de Errores:**
- **OSDMenu Configurator** ahora tiene la ilustración correcta en la pestaña Aplicaciones en **[OPL](#open-ps2-loader-opl)**
- Se corrigió el cambio de nombre de `.vcd` a `.VCD` en sistemas de archivos que no distinguen entre mayúsculas y minúsculas
- Elimina la carpeta `neutrino` existente antes de actualizar para evitar conflictos
- Garantiza que los archivos de configuración de OSDMenu terminen con una nueva línea antes de agregar contenido

**README**:
- Nueva sección [Opciones de arranque](#opciones-de-arranque)
- Se agregó una tabla para [teclas de acceso rápido de POPSarter](#iniciador-pop)
- Se agregó Debian a la lista de [sistemas operativos recomendados](#instalación-en-linux)
- Se agregaron nuevas funciones a la sección [Instalar juegos y aplicaciones](#instalar-juegos-y-aplicaciones)
- Se cambiaron las referencias de Neutrino a [NHDDL](#nhddl), lo que refleja cómo se lanzan ahora los juegos.
- Mejoras generales

**27 de Marzo de 2026: Tarjetas de Memoria Virtuales (VMCs) para Juegos de PS2**
- El **[Instalador de juegos](#instalar-juegos-y-aplicaciones)** ahora ofrece la opción de habilitar **[VMC](#tarjetas-de-memoria-virtuales)** para juegos de PS2. No es necesaria ninguna configuración adicional
- Esta función es compatible con **[OPL](#open-ps2-loader-opl)** y **[NHDDL](#nhddl)**
- Compatible con **[Grupos de VMC](#tarjetas-de-memoria-virtuales)**

**26 de Marzo de 2026 - Actualización 4.2.0: Nuevos Canales en Línea Más Localización en Francés**
- Software del sistema PSBBN actualizado al parche 4.2.0
- El canal de juego ha cambiado de nombre a **[Canal de Internet](#canal-de-internet)**, lo que refleja su enfoque en línea.
- Se agregaron nuevos canales en línea: BANDAI CHANNEL, So-Net y BIGLOBE
- Descargue el nuevo avance del juego en mayor calidad, con miniaturas
- El soporte en francés ahora está disponible para PSBBN
</details>

<details>
<summary>05 de marzo de 2026: instaladores de películas y fotografías, OSDMenu Configurator y más.</summary>
<p><p>

[![¡Instaladores de Películas y Fotografías, OSDMenu Configurator y Más!](https://github.com/user-attachments/assets/f0fae1ee-bf04-4aea-88a6-89e030926282)](https://youtu.be/_jKzzsClgOY)

**Más Idiomas:**
- Además de inglés, japonés y alemán, PSBBN ahora está disponible en italiano, portugués brasileño y español.

**[Actualizar el Software del Sistema PS2:](#actualizar-el-software-del-sistema-ps2)**
- Reemplaza **Actualizar el software PSBBN**. Esta nueva opción actualiza el software del sistema **[PSBBN](#psbbn)** y **[OSDMenu](#hosdmenu)**.
- **PSBBN Definitive Project** **[Menú Principal](#menú-principal)** ahora muestra una notificación cuando **actualizaciones de software del sistema PS2** están disponibles

**[Instalar Películas:](#instalar-películas)**
- La opción **[Instalar películas](#instalar-películas)** se ha agregado al **[Menú Instalar medios](#instalar-medios)**
- Ahora puede colocar una variedad de formatos de video, incluidos `MP4`, `M4V`, `MKV`, `VOB` y más, en la carpeta `movie`.
- Al seleccionar **[Instalar películas](#instalar-películas)** se convertirán los archivos de vídeo al formato `PSM` compatible con **[PSBBN](#psbbn)**
- Los vídeos se podrán reproducir en el **[PSBBN Movie Channel](#canal-de-peliculas)**

**[Instalar Fotos:](#instalar-fotos)**
- La opción **[Instalar fotos](#instalar-fotos)** se ha agregado al **[Menú Instalar medios](#instalar-medios)**
- Ahora puede colocar una variedad de formatos de imagen, incluidos `JPG`, `PNG`, `TIF`, `GIF`, `BMP` y más, en la carpeta `photo`.
- Al seleccionar **[Instalar fotos](#instalar-fotos)** se convertirán los archivos de imagen a `PNG` y se les cambiará el tamaño si es necesario.
- Las imágenes se podrán ver en el **[Canal de fotos PSBBN](#canal-de-fotos)**

**[Menú OSD 1.2.0:](#osdmenu-mbr)**
- Tanto **[OSDMenu MBR](#osdmenu-mbr)** como **[HOSDMenu](#hosdmenu)** se han actualizado a la versión 1.2.0. El registro de cambios se puede encontrar **[aquí](https://github.com/pcm720/OSDMenu/releases)**
- Se ha agregado la aplicación **OSDMenu Configurator**. Esto te permite personalizar tu consola PS2 modificando la configuración tanto para **[OSDMenu MBR](#osdmenu-mbr)** como para **[HOSDMenu](#hosdmenu)**
- **OSDMenu Configurator** se instalará la próxima vez que seleccione **[Instalar juegos y aplicaciones](#instalar-juegos-y-aplicaciones)** desde **PSBBN Definitive Project [Menú Principal](#menú-principal)**. Se puede iniciar desde **[Colección de juegos](#colección-de-juegos)** o **[HOSDMenu](#hosdmenu)**

**[Instalaciones Exclusivas de HOSDMenu:](#instalar-hosdmenu-únicamente)**
- Aumento del tamaño máximo de partición **[POPS](#iniciador-pop)** a 130 GB.
- Se agregó selección de idioma. El instalador del juego utiliza el idioma seleccionado para los títulos de juegos y el **[mensaje POPS IGR](#salir-de-juegos)**
- **[HOSDMenu-only](#hosdmenu)** los usuarios ahora pueden cambiar el idioma de su instalación en el **[Menú de extras opcionales](#extras-opcionales)**

**[Cambiar Configuración de Pantalla:](#cambiar-la-configuración-de-la-pantalla)**
- Anteriormente bloqueado en **[PSBBN](#psbbn)**, ahora puedes cambiar la configuración de pantalla de tu sistema en el **[Menú de extras opcionales](#extras-opcionales)** a 4:3, completo o 16:9.
- **Nota:** Esta configuración la utilizan algunos juegos y **[HOSDMenu](#hosdmenu)**. No cambia la relación de aspecto de **[PSBBN](#psbbn)** en sí

**[Borrar Caché de Arte e Íconos:](#borrar-caché-de-arte-e-íconos)**
- En el **[Menú de extras opcionales](#extras-opcionales)**, ahora tienes la opción de borrar todas las ilustraciones e íconos descargados anteriormente que están almacenados localmente en tu PC.
- Es posible que desees borrar el caché si los juegos muestran ilustraciones incorrectas o de baja calidad, ya que es posible que ahora haya ilustraciones actualizadas disponibles.
- Al ejecutar **[Game Installer](#instalar-juegos-y-aplicaciones)** se descargarán las ilustraciones y los íconos más recientes.

**[PSBBN Launcher For Windows:](#instalación-en-windows)**
- Se agregó soporte para instalar juegos desde una unidad de red.
- Se agregó un mensaje que muestra los archivos compatibles para **[Movie Installer](#instalar-películas)** y **[Photo Installer](#instalar-fotos)**
- Mensaje de advertencia de capacidad mínima de la unidad corregido
- Corrección de errores

**Correcciones de Errores y Mejoras:**
- Logotipo de PS2 habilitado al iniciar discos físicos de juegos de PS2 para instalaciones nuevas. Los usuarios que actualicen pueden activar esta opción usando **OSDMenu Configurator**. **[MechaPwn](https://github.com/MechaResearch/MechaPwn)** los usuarios ahora pueden iniciar discos importados y maestros sin omitir el logotipo de PlayStation 2 o encontrar una pantalla con el logotipo dañado
- Al **[reasignar los botones Cruz y Círculo](#reassign-X-and-Círculo-buttons)**, su preferencia ahora se almacena y ya no se restablece al instalar actualizaciones
- Se mejoró la extracción de ID de título de archivos VCD
- PSBBN El instalador muestra los requisitos de tamaño típicos para música y películas al crear particiones
- Se utiliza un archivo de registro separado al instalar y actualizar
- Se corrigió la extracción de PSU cuando los nombres de carpeta superan los 12 caracteres
- Se solucionó un problema con **[Atajo Menu Navigator](#colección-de-juegos)** que se eliminaba al reiniciar
- Cálculos de capacidad fija y espacio disponible para unidades de menos de 128 GB
- Se agregó un retraso entre el montaje y el desmontaje de sistemas de archivos para mejorar la confiabilidad
- Se corrigió el seguimiento de errores para SQLite
- Descargas de arte mejoradas para las aplicaciones `SAS` y `ELF`
</details>

<details>
<summary>08 de enero de 2026 - PSBBN Definitive Project: nuevo nombre y soporte multilingüe</b></summary>
<p><p>

[![PSBBN Definitive Project: Nuevo Nombre y Soporte Multilingüe](https://github.com/user-attachments/assets/32bb93f2-c009-4b82-ba62-67933ff30e83)](https://www.youtube.com/watch?v=dvCt_ExHwro)

El parche definitivo en inglés PSBBN comenzó su vida en 2023 como un parche en inglés para PSBBN; este trabajo se ha expandido constantemente mucho más allá de su alcance original. En el futuro, ahora se denominará colectivamente **PSBBN Definitive Project**.

PSBBN ahora está disponible en inglés, alemán, italiano y japonés original, y pronto habrá una traducción al francés. Podrá elegir entre varios idiomas al instalar PSBBN. El idioma también se puede cambiar más adelante en el **[Menú Extras](#extras-opcionales)**.

Cuando el idioma está configurado en japonés, los títulos de los juegos de la región japonesa se muestran en japonés y se ordenan en orden “gojūon” (五十音) tanto en **[Colección de juegos](#colección-de-juegos)** como en el **[Navegador HOSDMenu](#hosdmenu)**. Además, también se puede acceder a los canales japoneses originales en línea desde el **[Canal de Internet](#canal-de-internet)**.

**Notas de Versión Completas**  

- **¡NUEVO!** PSBBN Traducción al alemán de [Argo707](https://github.com/Argo707)
- Traducción al inglés mejorada
- Canales en línea japoneses originales restaurados

**[Instalador PSBBN:](#instale-psbbn-y-hosdmenu)**
- Se agregó una opción para seleccionar un idioma al instalar PSBBN
- Al seleccionar japonés, también se instalará el japonés original **[canales en línea](#canal-de-internet)**

**[Actualización del Software PSBBN:](#actualizar-el-software-del-sistema-ps2)**
- Ahora actualiza el software del sistema PSBBN y el paquete de idioma a la última versión
- Cuando el idioma está configurado en japonés, los canales en línea también se actualizan

**[Extras Opcionales:](#extras-opcionales)**
- Se agregó la opción de cambiar el idioma de PSBBN en el menú **[Extras opcionales](#extras-opcionales)**

**[Instalador del Juego:](#instalar-juegos-y-aplicaciones)**
- Cuando el idioma está configurado en japonés, los títulos de los juegos de la región japonesa se mostrarán en japonés y se ordenarán en orden “gojūon” (五十音)
- El mensaje POPS IGR está instalado para el idioma seleccionado
- Los manuales de juegos de PS1 están instalados para el idioma seleccionado

**`TitlesDB_PS1.csv` y `TitlesDB_PS2.csv`:**  
- Se agregaron títulos de juegos japoneses para todos los juegos de la región japonesa.

`list-Builder.py`:**
- Actualizado para manejar títulos de juegos japoneses.

**PSBBN Definitive Patch Actualizado a V4.1.0**
- Se actualizó el enlace al nuevo canal Konami para instalaciones no japonesas
- Se modificó `fstab` para montar la partición `channels`

**General**:
- El idioma del sistema ahora está configurado en el idioma PSBBN seleccionado y ya no se restablece a inglés o japonés al iniciar PSBBN
- Se agregó `libicu-dev` y `pkg-config` a las dependencias
- Mensaje IGR POPS en inglés mejorado
- Se agregó una advertencia para evitar que los scripts internos se ejecuten directamente
- Se agregó una verificación de validación de instalación para cancelar instalaciones no compatibles.
- **[NHDDL](#nhddl)** actualizado a la versión 1.2.1
</details>

<details>
<summary>14 de noviembre de 2025 - PSBBN Definitive Patch v4.0 - ¡Menú OSDM, adaptadores HDD de terceros y más!</b></summary>
<p><p>

[![PSBBN Definitive Patch V4.0: Menú OSDM, Adaptadores HDD de Terceros y Más.](https://github.com/user-attachments/assets/1a3f2d69-6bec-4fe4-aa27-c367f5d98f98)](https://www.youtube.com/watch?v=fT368C90Trc)

**[¡NUEVO! OSDMenu MBR:](#osdmenu-mbr)**  
Se reemplazó la aplicación MBR original de Sony con **[OSDMenu MBR](#osdmenu-mbr)**, una alternativa casera que:
- Maneja el inicio de juegos y aplicaciones directamente en lugar de depender de **BBN Launcher (BBNL)**
- Mejora la velocidad de arranque
- Los juegos ahora se inician hasta 6 segundos más rápido
- Elimina la necesidad de **PlayStation 2 Basic Boot Loader (PS2BBL)** — **[OSDMenu MBR](#osdmenu-mbr)** admite de forma nativa el inicio de ELF manteniendo presionado un botón del gamepad al inicio, lo que reduce drásticamente los tiempos de arranque en comparación con **PS2BBL**
- PS2 Linux ahora se inicia directamente manteniendo presionado ○ al encender en lugar de interrumpir **[PSBBN](#psbbn)** inicio
- Se eliminó la aplicación **"Launch Disc"**: simplemente inserte un disco de juego para jugar, compatible con **[Game ID, MechaPwn y PS1VmodeNeg integrado!](#lanzamiento-de-discos-de-juegos-de-ps1-y-ps2)**
- Mejora el manejo de **[Retro GEM Game ID](#id-del-juego)**: **[PSBBN](#psbbn)** y **[HOSDMenu](#hosdmenu)** ahora configuran un **Game ID** en el arranque, eliminando la necesidad del **Restablecedor de Retro GEM Game ID**
- Cuando se utiliza una **MemCard Pro 2 o SD2PSX**, ya no se generan **VMC** innecesarios al iniciar juegos de PS1 con **[POPSarter](#iniciador-pop)** u otras aplicaciones caseras.

**[¡NUEVO! HOSDMenu:](#hosdmenu)**  
Parcha **HDD-OSD** e introduce varias mejoras:
- Admite unidades más grandes, anteriormente limitadas a 1 TB
- Inicie aplicaciones caseras directamente desde el **menú OSDSYS**
- Inicie **[aplicaciones compatibles con SAS](#save-application-system-sas)** desde tarjetas de memoria y desde la unidad interna en **[Navegador 2.0](#hosdmenu)**
- Soporte para iniciar aplicaciones desde dispositivos MMCE, MX4SIO, UDPBD, iLink y discos duros con formato APA y exFAT
- GSM integrado para juegos y aplicaciones en disco
- Soporte para 1080i y 480p
- Y más: consulte el [repositorio de GitHub](https://github.com/pcm720/OSDMenu) para obtener todos los detalles.

**[¡NUEVO! Instale PSBBN y HOSDMenu:](#instale-psbbn-y-hosdmenu)**
- El instalador PSBBN ahora instala **[HOSDMenu](#hosdmenu)** junto con **[PSBBN](#psbbn)**
- Muestra las últimas notas de la versión al instalar y actualizar
- Admite unidades más pequeñas: capacidad mínima reducida de 200 GB a 32 GB
- Aumento del tamaño máximo de partición APA a 112 GB
- Después de la partición, cualquier espacio no asignado ahora se asigna a la partición **[OPL](#open-ps2-loader-opl)**
- Aconseja a los usuarios que consulten [archive.org](https://archive.org/) o utilicen una VPN si fallan las descargas.

**[¡NUEVO! Instale HOSDMenu Únicamente:](#instalar-hosdmenu-únicamente)**
- Agrega una opción para instalar **[HOSDMenu](#hosdmenu)** únicamente (para usuarios con adaptadores HDD de terceros)
- Cree una partición **[POPS](#iniciador-pop)** de tamaño personalizado (hasta 118 GB), asignando automáticamente el espacio restante a la partición **[OPL](#open-ps2-loader-opl)** (hasta 2 TB)

**[Instalador del Juego:](#instalar-juegos-y-aplicaciones)**
- **[Game Installer](#instalar-juegos-y-aplicaciones)** ahora requiere **PSBBN Definitive Project v4.0.0** y superior o **[HOSDMenu-only](#instalar-hosdmenu-únicamente)**
- Agrega compatibilidad solo con configuraciones **[HOSDMenu](#hosdmenu)**
- Actualizaciones **[OSDMenu MBR](#osdmenu-mbr)** y **[HOSDMenu](#hosdmenu)** si hay versiones más nuevas disponibles
- Actualiza **Menu Navigator** con accesos directos al iniciador de juegos seleccionado (**[OPL](#open-ps2-loader-opl)** o **[NHDDL](#nhddl)**), **[HOSDMenu](#hosdmenu)** y **[wLaunchELF_ISR](#wlaunchelf_isr)**
- Actualiza la configuración **[HOSDMenu](#hosdmenu)** para mostrar las aplicaciones homebrew instaladas en el **menú OSDSYS**
- Convierte automáticamente archivos `BIN/CUE` de PS1 a `VCD` y archivos `BIN/CUE` de PS2 a `ISO`
- Los juegos de PS1 ahora se copian y sincronizan a través de `PFS FUSE` usando `rsync`, con progreso visible durante la transferencia
- Copia solo archivos válidos de juegos y homebrew al sincronizar o agregar juegos y aplicaciones. `rsync` ahora ignora los archivos de metadatos `:Zone.Identifier` de Windows que podrían provocar errores de sincronización
- Pone en mayúsculas automáticamente las extensiones `.VCD` en minúsculas para garantizar la compatibilidad con **[POPSarter](#iniciador-pop)**
- Se reubicaron `OPNPS2LD.ELF` y `nhddl.elf` a `__system/launcher` y `POPSTARTER.ELF` a `__common/POPS` desde exFAT.

`list-Builder.py`:**
- Ahora escanea la partición PFS `__.POPS` en busca de archivos `VCD` en lugar de la carpeta `POPS` local.

`art_Downloader.py`:**
- Se convirtió `art_downloader` de JavaScript a Python, eliminando dependencias en Node.js, npm, Puppeteer y Chromium.

**[Instalar Música:](#instalar-música)**
- Agrega soporte para álbumes multidisco usando números de disco de metadatos
- Utiliza metadatos de **Artista del álbum** para álbumes y metadatos de **Artista** para pistas individuales
- Reemplaza los caracteres no admitidos en los metadatos con alternativas seguras
- Agrupa claramente los archivos omitidos por motivo

**[Instalador de PS2 Linux:](#instalar-ps2-linux)**
- Actualiza la configuración **[OSDMenu MBR](#osdmenu-mbr)** para habilitar el arranque de PS2 Linux.

**[PSBBN Launcher For Windows:](#instalación-en-windows)**
- Capacidad mínima del disco reducida de 200 GB a 32 GB
- Las indicaciones del usuario ahora son más descriptivas
- Impide que los usuarios seleccionen una carpeta WSL para almacenar sus juegos y medios
- Hace cumplir la compilación 19041 como la versión mínima de Windows requerida para ejecutar WSL
- Ejecuta `wsl --install --no-distribution` para garantizar que WSL 2 esté disponible
- Utiliza explícitamente WSL 2 al instalar Distribución PSBBN
- Comprueba que apt haya instalado correctamente git; De lo contrario, sale correctamente
- Se actualizó la entrada del número de disco para admitir valores mayores que 9
- Sale correctamente si falla el montaje del disco.

**[NHDDL:](#nhddl)**
- Actualizado a la versión v1.2.0

**`Setup.sh` y `flake.nix`:**
- Se agregó `bchunk` a las dependencias.

**Archivo Tar del Parche Definitivo 4.0.0:**
- Corrige los permisos y la propiedad de los archivos
- Se eliminaron los archivos almacenados en caché y otros archivos innecesarios, lo que reduce el tamaño del archivo.
- Se agregaron carpetas adicionales para archivos **[HOSDMenu y HDD-OSD](#hosdmenu)**
- Se reemplazó **osdboot.elf** cifrado por una versión no cifrada

**General:**
- Se agregó soporte para sistemas ARM64. Probado en una Raspberry Pi con la última versión del sistema operativo Raspberry Pi
- `BOOT.ELF` reemplazado por [compatible con SAS](#save-application-system-sas) [wLaunchELF_ISR](#wlaunchelf_isr) versión 4.43x_isr-bb13043
- Se eliminó `PS1VModeNeg.elf`
- Cambia la configuración regional de `en_US.UTF-8` a `C.UTF-8` (algunos sistemas carecían de `en_US.UTF-8`), lo que garantiza que la salida del script y los registros permanezcan en inglés y previene fallas relacionadas
- Manejo mejorado del montaje y desmontaje de particiones APA
- Corrección de errores
- Licencias de software agregadas

</details>

<details>
<summary>09 de septiembre de 2025: PSBBN Launcher for Windows: instalación y configuración sencillas</b></summary>
<p><p>

[![PSBBN Launcher For Windows: Instalación y Configuración Sencillas](https://github.com/user-attachments/assets/981e4abc-10b0-49d2-8d52-3e19ea80650b)](https://www.youtube.com/watch?v=O5ZvJoW4oNw)

**[¡NUEVO! PSBBN Launcher for Windows](#instalación-en-windows)** - La nueva forma de instalar **PSBBN Definitive Project** en Windows 10 y 11.
Un agradecimiento especial a Yornn por todo su trabajo en esta función.

</details>

<details>
<summary>28 de agosto de 2025 - PSBBN Definitive Patch v3.00 - ¡Instalador de música, sistema de menús, instalaciones más rápidas y más!</b></summary>
<p><p>

[![PSBBN Parche Definitivo en Inglés 3.0](https://github.com/user-attachments/assets/3b82d809-28d5-4675-87c2-c7f1abf96ae6)](https://www.youtube.com/watch?v=lUMKZck6G08) 
  
**[¡NUEVO! Sistema de Menú:](#menú-principal)**
- Nuevo sistema de menú central en lugar de scripts separados, lo que facilita la navegación por las diversas funciones de **PSBBN Definitive Project**
- La configuración ahora se ejecuta automáticamente si se detectan dependencias faltantes.

**[¡NUEVO! Instalador de Música:](#instalar-música)**
- Instale música para reproducirla en **[PSBBN Music Channel](#canal-de-música)**. Formatos admitidos: `.mp3`, `.m4a`, `.flac` y `.ogg`

**[¡NUEVO! Instalador PSBBN:](#instale-psbbn-y-hosdmenu)**
- **[PSBBN](#psbbn)** ha realizado una transición completa de ReiserFS (un sistema de archivos antiguo que ya no es compatible) a ext2, lo que permite el acceso directo a todas las particiones BBN.
- El nuevo instalador PSBBN funciona con un archivo tar en lugar de una imagen de disco, lo que reduce el tamaño de descarga y mejora drásticamente el tiempo de instalación
- Al realizar la instalación, puede establecer un tamaño personalizado para la partición `contents` utilizada para películas y fotos (anteriormente limitada a 5 GB)
- Tamaño máximo aumentado de las particiones de música, contenidos y POPS, ahora hasta 111 GB

**[¡NUEVO! Actualizador PSBBN:](#actualizar-el-software-del-sistema-ps2)**
- Permite actualizar a la última versión del Proyecto Definitivo directamente desde el menú. ¡No se requiere memoria USB ni teclado USB!

**[Instalador del Juego:](#instalar-juegos-y-aplicaciones)**
- El instalador del juego ahora ofrece una solución HDTV para juegos de PS1, lo que les permite visualizarse en televisores que no admiten 240p
- Corrección de errores y extracción mejorada de ID de juego para archivos ISO y VCD.
- Extrae el ID del juego directamente de los archivos ZSO descomprimiendo solo una parte de la imagen del disco; Ya no es necesario descomprimir completamente ni cambiar el nombre de los archivos ZSO, lo que mejora enormemente el tiempo de procesamiento.

**[Extras:](#extras-opcionales)**
- PS2 Linux ahora es una instalación opcional. Puede establecer un tamaño personalizado para la partición de su hogar. PS2 Linux también se puede reinstalar si tienes problemas
- Intercambia las funciones de los botones Cruz y Círculo de tu controlador. Elija entre el diseño estándar (Cruz = Confirmar, Círculo = Atrás) o el diseño alternativo (Círculo = Confirmar, Cruz = Atrás)

**HDD-OSD (Navegador 2.0):**
- Nuevo ícono PSBBN diseñado por Yornn
- Nuevo color de fondo mejorado al visualizar íconos de juegos

</details>

<details>
<summary>17 de julio de 2025 - Parche definitivo v2.11 - ¡Seguridad de arranque parcheada! ¡Intercambio de botones, Grupos de VMC y más!</b></summary>
<p><p>

[![PSBBN Definitive Patch V2.11](https://github.com/user-attachments/assets/49511803-429b-4cd8-8546-40334be3f244)](https://www.youtube.com/watch?v=kgXe8rlqsr0)

**PSBBN Actualizado al Parche Definitivo V2.11**

El parche v2.11 se puede instalar ejecutando el [script del instalador PSBBN] (#instale-psbbn-y-hosdmenu) (se perderán todos los datos) o mediante la nueva opción **Actualizar el software PSBBN** en el [script adicional] (#extras-opcionales).

**Nuevo en el Parche Definitivo V2.11:**
- Seguridad de arranque parcheada. Se ha omitido la comprobación de seguridad CRC en el ELF de arranque de PSBBN, lo que permite la carga de núcleos personalizados.
- Los botones × y ○ se han intercambiado: × ahora es Confirmar y ○ ahora es Atrás.
- Se agregó soporte para el control remoto del DVD de PlayStation 2. Los botones `PLAY`, `PAUSE`, `STOP`, `PREV`, `NEXT`, `SCAN` y `DISPLAY` ahora se pueden usar durante la reproducción de música y películas en los canales [Música](#canal-de-música) y [Película](#canal-de-peliculas). El botón `Confirmar` también se puede utilizar al navegar por los menús.
- La **Guía de PlayStation BB** se ha actualizado para reflejar el intercambio de botones y la reubicación de la [Colección de juegos](#colección-de-juegos). Se ha agregado una nueva sección que cubre los canales en línea. Numerosas mejoras en la traducción al inglés.
- Mejora el proceso de actualización. No se necesitarán una unidad USB ni un teclado para futuras actualizaciones.

`02-PSBBN-Installer.sh`:**
- Ahora puede establecer un tamaño personalizado para la partición [POPS](#iniciador-pop). Anteriormente, llenaba todo el espacio restante después de crear la partición de música.

**`03-Game-Installer.sh`, `ps2iconmaker.sh` y `txt_To_Icon_Sys.py`:**

- Los juegos multidisco de PS1 ahora admiten el intercambio de discos sin configuración adicional. Se crea un archivo `DISCS.TXT` para cada juego multidisco. Los juegos multidisco ahora también comparten un [POPSarter Tarjeta de Memoria Virtual (VMC)](#tarjetas-de-memoria-virtuales)
- [POPStarter Grupos de VMC](#tarjetas-de-memoria-virtuales) para juegos de PS1: los juegos que pueden interactuar con los datos guardados de otros ahora comparten un único VMC. Por ejemplo, las licencias obtenidas en Gran Turismo se pueden transferir a Gran Turismo 2, y Psycho Mantis de Metal Gear Solid puede comentar sobre otros juegos de Konami que hayas jugado.
- Los VMC ahora muestran títulos más claros en **Save Data Management** y **Browser 2.0** con íconos personalizados para cada juego y grupo.
- El instalador del juego ahora genera automáticamente íconos HDD-OSD (Navegador 2.0) si no se encuentran en [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database). Si las imágenes de portada de un juego están disponibles en OPL Manager Art Database, se generará automáticamente un ícono 3D para el juego. También se crean íconos 3D para VMC cuando hay un logotipo de juego disponible. Todos los íconos recién generados se agregan automáticamente a HDD-OSD Icon Database y se informan los íconos que faltan.
- Se corrigió un error por el cual se podía mostrar información incorrecta del editor para archivos `ELF`

`list-Builder.py`:**

- Extracción de ID de juego mejorada para casos extremos. Ahora maneja ID no estándar como `LSP99016.101` y juegos de PS1 con archivos `system.cnf` no estándar.

**Neutrino Actualizado a la Versión 1.7.0**

- El registro de cambios completo de Neutrino se puede encontrar [aquí](https://github.com/rickgaiser/neutrino/releases/tag/v1.7.0)

**Open PS2 Loader Actualizado a V1.2.0 Beta-2210-6b300b0**
- Agrega soporte para Grupos de VMC y corrección de errores.

**LanzamientoELF**
- Actualizado a [wLaunchELF v4.43x_isr](#wlaunchelf_isr). Mejora la estabilidad y agrega soporte para exFAT en unidades externas y MMCE (exploración de tarjetas SD en MemCard Pro 2/SD2PSX).

</details>

<details>
<summary>05 de junio de 2025 - PSBBN Definitive Patch v2.10 – ¡Cambios en el instalador de juegos importantes y más!</b></summary>
<p><p>

[![PSBBN Definitive Patch V2.10](https://github.com/user-attachments/assets/ff4e6e5b-8556-4fe2-88b2-99e7eb09121c)](https://www.youtube.com/watch?v=XTacIPOGAwE)

**PFS Shell.elf y HDL Dump.elf:**

- PFS Shell actualizado para admitir la creación de particiones APA de 8 MB
- HDL Dump actualizado para modificar correctamente sus encabezados

**Imagen de Disco PSBBN Actualizada a la Versión 2.10:**

- Disco creado con una nueva versión de PFS Shell para compatibilidad total con particiones APA de 8 MB
- Se agregó un enlace directo a la [Colección de juegos](#colección-de-juegos) en el menú superior.
- Tiempo de inicio mejorado para usuarios sin un cable Ethernet conectado
- Se modificó el script de inicio para formatear e inicializar la partición de Música, permitiendo que sea más pequeña o más grande que antes.
- Retraso reducido antes de que se registren las pulsaciones de botones al iniciar Linux
- La partición PS2 Linux ahora usa `ext2` en lugar de `reiserfs`
- Se eliminó la configuración del ISP del menú superior
- Se eliminó el acceso directo Open PS2 Loader del Menu Navigator (el usuario puede agregar un acceso directo al iniciador del juego que elija manualmente)
- Accesos directos modificados para [LaunchELF](https://github.com/ps2homebrew/wLaunchELF) y [Launch Disc](#launch-disc)
- Se actualizó la página Acerca de PlayStation BB Navigator
- Se habilitó el acceso telnet a PSBBN para fines de desarrollo
- Correcciones a la traducción al inglés

`02-PSBBN-Installer.sh`:**

- Evita que el script instale PSBBN Definitive Patch si la versión es inferior a 2.10
- Particiona el espacio restante de los primeros 128 GB de la unidad:
  - La partición de música ahora puede oscilar entre 1 GB y 104 GB
  - La partición [POPS](#iniciador-pop) ahora puede oscilar entre 1 GB y 104 GB
  - Espacio reservado para 800 **particiones BBNL**
- Se eliminó el instalador [POPS](#iniciador-pop) (ahora manejado por el script del instalador del juego)
- El código se ha limpiado y optimizado significativamente.

`03-Game-Installer.sh`:**

- Se agregó una advertencia para los usuarios que ejecutan PSBBN Definitive Patch por debajo de la versión 2.10
- La unidad PS2 ahora se detecta automáticamente
- Se agregó una opción para establecer una ruta personalizada a la carpeta `games` en su PC
- Permite agregar nuevos juegos y aplicaciones sin requerir una sincronización completa
- **BBNL** tamaño de partición reducido de 128 MB a 8 MB, lo que permite mostrar hasta 800 juegos/aplicaciones en la [Colección de juegos](#colección-de-juegos)
- Se corrigió un error que impedía que se iniciaran juegos con números en superíndice en sus títulos
- Mejoras generales en la verificación de errores y mensajería
- Se corrigieron problemas al detectar el éxito/fallo de algunos comandos `rsync`
- `rsync` ahora se ejecuta solo cuando es necesario
- Proceso de actualización mejorado para [POPSarter](#iniciador-pop), [OPL](#open-ps2-loader-opl), [NHDDL y Neutrino](#nhddl)
- Game Installer ahora instala archivos binarios [POPS](#iniciador-pop) si faltan
- Número reducido de comandos ejecutados con `sudo`
- Los archivos `ELF` ahora se instalan en carpetas e incluyen un `title.cfg`
- El código se ha limpiado y optimizado significativamente.

`list-Builder.py`:**

- Se fusionaron `list-builder-ps1.py` y `list-builder-ps2.py` en un solo script
- Ahora extrae los ID de los juegos de PS1 y PS2.

`list-Sorter.py`:**

- La lógica de clasificación de juegos se ha movido aquí desde los scripts de creación de listas anteriores
- La clasificación se ha mejorado significativamente

**General**

- Los scripts del instalador PSBBN y del instalador del juego ahora evitan que la PC entre en suspensión durante la ejecución
- Se agregó una verificación en cada script para garantizar que se ejecute usando Bash
- Actualizado README

</details>

<details>
<summary>01 de mayo de 2025: ¡SAS, HDD-OSD, PS2BBL y más!</b></summary>

[![¡SAS, HDD-OSD, PS2BBL y Más!](https://github.com/user-attachments/assets/be5b32d2-665c-4505-aefe-3c9ab864f72a)](https://www.youtube.com/watch?v=vpbHlS8nY58)

- Se agregó soporte para [Save Application System (SAS)](#save-application-system-sas). Los archivos `PSU` ahora también se pueden colocar en la carpeta local `games/APPS` de su PC y se instalarán mediante el script `03-Game-Installer.sh`.
- Se agregó soporte para HDD-OSD al script `03-Game-Installer.sh`. Los iconos 3D ahora se descargan desde [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database)
- Nuevo script: [04-Extras.sh](#extras-opcionales). Se agregó la capacidad de instalar HDD-OSD y [PlayStation 2 Basic Boot Loader (PS2BBL)](#playstation-2-basic-boot-loader-ps2bbl)
- Cree sus propios íconos HDD-OSD con las [Plantillas de íconos HDD-OSD] (https://github.com/CosmicScale/HDD-OSD-Icon-Database/releases/download/v1.0.0/HDD-OSD-Icon-Templates.zip)
- Traduzca PSBBN usando el [Paquete de traducción](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/issues/299) para localizar el software a diferentes idiomas.

</details>

<details>
<summary>28 de marzo de 2025: ¡Lanzador de cerveza casera y más!</b></summary>
<p><p>

[![¡Lanzador de Cerveza Casera y Más!](https://github.com/user-attachments/assets/57e7842c-f5b5-46b0-950e-246eebfb0e4a)](https://www.youtube.com/watch?v=q9LvE_OPIPo)

- [Open PS2 Loader](#open-ps2-loader-opl) actualizado a la versión 1.2.0-Beta-2201-4b6cc21:
  - Modo BDM UDMA máximo limitado a UDMA4 para evitar problemas de compatibilidad con varios adaptadores SATA/IDE2SD
- Se agregó un manual para juegos de PS1. Se puede acceder a él en la [Colección de juegos](#colección-de-juegos) seleccionando un juego, presionando **△** y luego seleccionando **Manual**
- Se realizó la transición a **BBN Launcher (BBNL)** versión 2.0:
  - Se eliminó la compatibilidad con PFS a favor de cargar [OPL](#open-ps2-loader-opl), [POPSarter](#iniciador-pop), [Neutrino](#nhddl) y archivos de configuración desde la partición exFAT para acelerar la inicialización.
  - Se movió **BBNL** al encabezado APA para mejorar aún más los tiempos de carga.
  - Se eliminó la dependencia de archivos [POPSarter](#iniciador-pop) `ELF` renombrados para iniciar VCD de PS1; [POPStarter](#iniciador-pop) ahora se inicia directamente con un argumento de inicio.
  - [NHDDL](https://github.com/pcm720/nhddl) ahora se inicia en modo ATA, lo que mejora el tiempo de inicio y evita posibles mensajes de error.
- Actualizado [Neutrino](#nhddl) a la versión 1.6.1
- Actualizado [NHDDL](#nhddl) a la versión MMCE + HDL Beta 4.17
- Se agregó la portada de las [copias de seguridad de OPL Manager Art DB] (https://oplmanager.com/site/index.php?backups). Las ilustraciones de los juegos de PS2 ahora se muestran en OPL/NHDDL
- Se agregó compatibilidad con homebrew al script `03-Game-Installer.sh`. Los archivos `ELF` colocados en la carpeta local `games/APPS` de su PC se instalarán y aparecerán en la [Colección de juegos](#colección-de-juegos) en PSBBN y en la pestaña Aplicaciones en OPL.
- Las aplicaciones ahora admiten [Game ID](#id-del-juego) tanto para Pixel FX Retro GEM como para MemCard Pro/SD2PSX.

</details>

<details>
<summary>19 de febrero de 2025: BBN Launcher, Neutrino y NHDDL</b></summary>
<p><p>

[![Lanzador BBN, Neutrino y NHDDL](https://github.com/user-attachments/assets/8007d102-3019-4037-8c52-24d1454777da)](https://www.youtube.com/watch?v=0vpSiAa6ITc)

- [OPL-Launcher-BDM](https://github.com/CosmicScale/OPL-Launcher-BDM) ha sido reemplazado por **BBN Launcher (BBNL)**
- Se agregó compatibilidad con [Neutrino](#nhddl). Ahora puedes elegir entre [Open PS2 Loader](#open-ps2-loader-opl) y [Neutrino](#nhddl) como iniciador de juego.
- Al usar Neutrino como iniciador de juegos, se puede usar [NHDDL](#nhddl) para realizar configuraciones por juego.

</details>

<details>
<summary>22 de enero de 2025: ID del juego, base de datos de arte PSBBN, tutorial actualizado y más.</b></summary>

[![ID del Juego, Base de Datos de Arte PSBBN, Tutorial Actualizado y Más.](https://github.com/user-attachments/assets/1bae03fe-b3eb-447e-99da-8f184279a848)](https://www.youtube.com/watch?v=sHz0yKYybhk)

- Se agregó compatibilidad con [Game ID](#id-del-juego) para Pixel FX Retro GEM, así como para MemCard Pro 2 y SD2PSX. Funciona tanto para juegos de PS1 como de PS2.
- Los juegos de PS2 ahora se inician hasta 5 segundos más rápido
- Conflicto resuelto con dispositivos de almacenamiento masivo (USB, iLink, MX4SIO). Los juegos ahora se inician sin problemas si estos dispositivos están conectados
- Las aplicaciones ahora se actualizan automáticamente cuando sincronizas tus juegos
- El descargador de arte se ha mejorado para capturar significativamente más arte
- Manejo de errores mejorado en el script de instalación PSBBN
- El script de configuración se ha modificado para funcionar en entornos Linux en vivo sin problemas
- Se agregó soporte para distribuciones de Linux basadas en Arch y Fedora, además de Debian
- Se agregaron mensajes de confirmación al Script de instalación PSBBN al crear particiones
- Imagen PSBBN actualizada a la versión 2.01:
  - Configure la distribución del teclado USB en inglés de EE. UU. Presione `ALT+~` para alternar entre kana y entrada directa
  - Correcciones menores a la traducción al inglés
- Se agregó [Open PS2 Loader](#open-ps2-loader-opl) y [Disco de lanzamiento](#launch-disc) a la [Colección de juegos](#colección-de-juegos)
- El script del instalador del juego se ha actualizado para crear y eliminar particiones del juego según sea necesario. ¡Diga adiós a esos molestos marcadores de posición "Próximamente..."!
- Los archivos ubicados en las carpetas `CFG`, `CHT`, `LNG`, `THM` y `APPS` de tu PC ahora se copiarán en la unidad de PS2 durante la sincronización del juego
- Los scripts ahora se actualizan automáticamente cuando hay una actualización disponible
- Obra de arte optimizada
- Presentamos la [base de datos de arte PSBBN](https://github.com/CosmicScale/psbbn-art-database)
- Si no se encuentra la obra de arte en la [base de datos de arte PSBBN] (https://github.com/CosmicScale/psbbn-art-database), se intenta descargarla desde IGN. Las descargas de arte de IGN ahora se agregan automáticamente a la [base de datos de arte PSBBN](https://github.com/CosmicScale/psbbn-art-database), y las obras de arte faltantes también se informan automáticamente. Los envíos manuales son bienvenidos; consulte la [página de GitHub de la base de datos de arte PSBBN](https://github.com/CosmicScale/psbbn-art-database) para obtener más detalles.

</details>

<details>
<summary>11 de diciembre de 2024: PSBBN Parche definitivo en inglés 2.0</b></summary>
<p><p>

[![PSBBN Parche Definitivo en Inglés 2.0](https://github.com/user-attachments/assets/608c9430-25d8-4918-8111-023eac16ab62)](https://www.youtube.com/watch?v=ooH0FjltsyE)

- Lanzamiento inicial de la versión 2.0 del parche
- Los canales en línea de Bandai y SCEI se han agregado al canal de juego
- Arranque dual de PS2 Linux
- [wLaunchELF](https://github.com/ps2homebrew/wLaunchELF) preinstalado
- Compatibilidad con discos duros grandes: ya no se limita a 128 GB
- Presentamos [APA-Jail](#apa-jail), que permite que las particiones APA de PlayStation coexistan con una partición exFAT
- Presentamos [OPL-Launcher-BDM](https://github.com/CosmicScale/OPL-Launcher-BDM), que permite que los juegos de PS2 almacenados en la partición exFAT se inicien desde PSBBN
- Presentamos el [script del instalador PSBBN] (#instale-psbbn-y-hosdmenu):
  - Instala PSBBN, [binarios POPS y POPStarter](#iniciador-pop)
  - Particione los primeros 128 GB de la unidad como APA:
    - Cree hasta 700 particiones del iniciador OPL
    - Partición de música de tamaño personalizado desde 10 GB hasta un máximo de 97 GB
    - Espacio restante asignado a la partición [POPS](#iniciador-pop) para juegos de PS1
  - Crea una partición exFAT con espacio en el disco más allá de los primeros 128 GB para el almacenamiento de juegos de PS2
- Presentamos el [script del instalador del juego] (#instalar-juegos-y-aplicaciones):
  - Automatiza completamente la instalación de juegos de PS1 y PS2
  - Crea todos los recursos y metadatos
  - Descarga el arte del juego desde IGN

</details>  

# Guía de Instalación
**PSBBN Definitive Project** se ha traducido completamente al inglés, japonés, francés, español, alemán, italiano, portugués brasileño y húngaro. El idioma de su sistema operativo se detecta automáticamente y el proyecto se ejecuta en ese idioma, siendo el inglés de forma predeterminada si no está disponible.

## Requisitos
Para obtener la mejor experiencia, se recomienda un modelo PS2 Fat (series SCPH-30000 a SCPH-55000).

**Requisitos Mínimos:**
- Adaptador de disco duro de terceros
- Disco duro IDE o SATA (mínimo 32 GB[*](#problemas-conocidos))

**Configuración Recomendada:**
- Adaptador de red oficial de Sony
- Placa de actualización del adaptador SATA Kaico o BitFunx
- SSD SATA (256 GB a 2 TB)

**Notas:**
- Se recomienda una SSD SATA para [PSBBN](#psbbn), ya que la velocidad de acceso aleatorio mejorada da como resultado una capacidad de respuesta del menú más rápida.
- [PSBBN](#psbbn) no admite adaptadores HDD de terceros[*](#problemas-conocidos). Los adaptadores de terceros solo son compatibles con la [instalación exclusiva de HOSDMenu](#instalar-hosdmenu-únicamente).
- [PSBBN](#psbbn) y [HOSDMenu](#hosdmenu) son compatibles con los modelos PS2 Slim SCPH-700xx que utilizan un IDE Resurrector (o mod de hardware equivalente) y los primeros modelos de PS2 (series SCPH-10000 a SCPH-18000) con una carcasa de disco duro externa oficial. [Se requiere configuración adicional para ambas configuraciones](#consolas-anteriores-scph-1000018000-y-delgadas-scph-700xx).

**PSBBN Definitive Project** requiere una PC x86-64 o ARM64 para su instalación. Conecte el HDD o SSD a la PC mediante SATA o un adaptador USB.

## Instalación en Linux
Se admiten distribuciones basadas en Debian de 64 bits que utilizan `apt`, distribuciones basadas en Arch que utilizan `pacman` y distribuciones basadas en Fedora[*](#solución-de-problemas) que utilizan `dnf`. Los sistemas basados ​​en Nix también son compatibles mediante flakes. Las distribuciones recomendadas son Linux Mint, Debian y, para Raspberry Pi, Raspberry Pi OS.

**PSBBN Definitive Project Es Una Versión Continua. para Obtener Actualizaciones Automáticas y las Últimas Correcciones de Errores, Debe Instalar los Scripts Usando `git Clone`.**

Instale git, para distribuciones basadas en Debian ejecute:
```
sudo apt update
sudo apt install git
```
Clonar el repositorio:
```
git clone https://github.com/CosmicScale/PSBBN-Definitive-Project.git
```

Luego puede cambiar al directorio `PSBBN-Definitive-Project` y ejecutar `PSBBN-Definitive-Patch.sh`:
```
cd PSBBN-Definitive-Project
./PSBBN-Definitive-Patch.sh
```
## Instalación en Windows
La forma recomendada de instalar **PSBBN Definitive Project** en Windows es mediante **PSBBN Launcher for Windows**. **PSBBN Launcher for Windows** es compatible con las ediciones Windows 10 y 11 Home; Es posible que otras ediciones no sean compatibles. Para una experiencia sin problemas, asegúrese de que Windows esté completamente actualizado.

**Vídeotutorial:**

[![PSBBN Launcher For Windows: Instalación y Configuración Sencillas](https://github.com/user-attachments/assets/981e4abc-10b0-49d2-8d52-3e19ea80650b)](https://www.youtube.com/watch?v=O5ZvJoW4oNw)

**Habilitando la Virtualización:**  
Puede que sea necesario habilitar el modo SVM (para CPU AMD) o VT-x (para CPU Intel) en la configuración de su BIOS si aún no está habilitado. Las instrucciones sobre cómo hacer esto se pueden encontrar [aquí](https://www.elevenforum.com/t/enable-or-disable-cpu-virtualization-in-uefi-bios-firmware-settings-on-windows-pc.4928/).

Descargue **PSBBN Launcher for Windows [aquí](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/releases/download/latest/PSBBN-Launcher-For-Windows.ps1)**.

**Establezca la Política de Ejecución de PowerShell:**  
Antes de ejecutar el script por primera vez, debe cambiar la política de ejecución en PowerShell:
1. Abra una nueva ventana de PowerShell desde el **menú Inicio** buscando **PowerShell** y seleccione **Ejecutar como administrador**.
2. Escriba el siguiente comando y presione Confirmar:

```
Set-ExecutionPolicy -ExecutionPolicy Unrestricted
```

**Ahora Está Listo para Ejecutar el Script:**  
Haga clic derecho en `PSBBN-Launcher-For-Windows.ps1` y seleccione **Ejecutar con PowerShell**.

El guión:
- Configure automáticamente el **[Subsistema de Windows para Linux (WSL)](https://learn.microsoft.com/en-us/windows/wsl/about)**
- Le solicitará que seleccione la unidad de destino para instalar **[PSBBN y HOSDMenu](#instale-psbbn-y-hosdmenu)**, o una unidad que ya tenga una instalación existente.
- Le solicitará que seleccione una carpeta local en su PC donde se administrarán los juegos y los medios (por ejemplo, C:\PSBBN).
- Inicie **PSBBN Definitive Project** **[Menú Principal](#menú-principal)**

**Accediendo a PSBBN Definitive Project Menú Principal en el Futuro:**  
Simplemente haga clic derecho en `PSBBN-Launcher-For-Windows.ps1` y seleccione **Ejecutar con PowerShell**

**NOTA:**  
Es normal que la unidad seleccionada se desmonte en Windows mientras se ejecuta el script. Salga siempre de **[PSBBN Definitive Project Menú Principal](main-menu)** presionando `q`. Esto garantiza que la unidad se desmonte de forma segura de WSL y se devuelva a Windows. Para las unidades USB, recuerde expulsarlas también de la bandeja del sistema de Windows antes de desconectarlas.

Si experimenta algún problema al ejecutar **PSBBN Launcher for Windows**, consulte **[solución de problemas](#problemas-al-ejecutar-el-script)**.

## Menú Principal
Si es la primera vez que ejecuta el script, o si faltan las dependencias necesarias, el proceso de configuración instalará automáticamente todo lo necesario antes de que se muestre Menú Principal.

Desde Menú Principal, tendrá las siguientes opciones:

1. [Instalar PSBBN y HOSDMenu](#instale-psbbn-y-hosdmenu) (Se requiere adaptador de red oficial de Sony)
Realiza una instalación nueva de [PSBBN](#psbbn) y [HOSDMenu](#hosdmenu)

2. [Instalar HOSDMenu únicamente](#instalar-hosdmenu-únicamente) (se admiten adaptadores HDD de terceros)
Realiza una instalación nueva [HOSDMenu](#hosdmenu)

3. [Actualizar el software del sistema PS2](#actualizar-el-software-del-sistema-ps2)
Actualiza una instalación existente de [PSBBN](#psbbn) y [HOSDMenu](#hosdmenu) a la última versión

4. [Instalar juegos y aplicaciones](#instalar-juegos-y-aplicaciones)
Instala juegos de PS1 y PS2, además de aplicaciones caseras.

5. [Instalar medios](#instalar-medios)
    1. [Instalar música](#instalar-música)
    2. [Instalar películas](#instalar-películas)
    3. [Instalar fotos](#instalar-fotos)
    4. [Establecer ubicación de medios](#establecer-ubicación-de-medios)
    5. [Inicializar partición de música](#inicializar-partición-de-música)

6. [Extras opcionales](#extras-opcionales)
    1. [Instalar PS2 Linux](#instalar-ps2-linux)
    2. [Reasignar botones en forma de cruz y círculo](#reassign-X-and-Círculo-buttons)
    3. [Cambiar idioma](#cambiar-idioma)
    4. [Cambiar configuración de pantalla](#cambiar-la-configuración-de-la-pantalla)
    5. [Borrar caché de iconos y arte](#borrar-caché-de-arte-e-íconos)

## Instale PSBBN y HOSDMenu
Esta opción instala tanto [PSBBN](#psbbn) como [HOSDMenu](#hosdmenu). Se requiere un adaptador de red oficial de Sony[*](#problemas-conocidos). El instalador realiza las siguientes acciones:
- Formatea la unidad para una instalación limpia
- Descarga el software del sistema y el paquete de idioma más recientes [PSBBN](#psbbn) desde [archive.org](https://archive.org/)
- Instala [PSBBN](#psbbn), [OSDMenu MBR](#osdmenu-mbr) y [HOSDMenu](#hosdmenu)
- Establece el idioma de la interfaz para que coincida con su sistema operativo (el valor predeterminado es inglés si no está disponible)
- Si el idioma está configurado en japonés, descarga e instala [Canales en línea](#canal-de-internet) desde [archive.org](https://archive.org/)
- Le solicita que particione el disco

Tienes **114 GB** disponibles y se te pedirá que selecciones un tamaño para las siguientes particiones:
- Música (utilizada por el [Canal de Música](#canal-de-música))
- Contenidos (utilizados por el [Canal de películas](#canal-de-peliculas) y el [Canal de fotos](#canal-de-fotos))

Opcionalmente, puede reservar espacio en la unidad para uso futuro. Este espacio no se asigna y luego se puede utilizar para particiones APA. Si planeas instalar PS2 Linux, reserva al menos 3 GB.

Luego se crea una partición exFAT utilizando el espacio restante en el disco (hasta 2 TB) para almacenar juegos y aplicaciones.

## Instalar HOSDMenu Únicamente
Esta opción instala [HOSDMenu](#hosdmenu) sin [PSBBN](#psbbn) y es compatible con adaptadores HDD de terceros. El instalador realiza las siguientes acciones:
- Formatea la unidad para una instalación limpia
- Instala [OSDMenu MBR](#osdmenu-mbr) y [HOSDMenu](#hosdmenu)
- Establece el idioma de la interfaz para que coincida con su sistema operativo (el valor predeterminado es inglés si no está disponible)
- Le solicita que particione el disco

Opcionalmente, puede reservar espacio en la unidad para uso futuro. Este espacio no se asigna y luego se puede utilizar para particiones APA. Se puede reservar hasta el 50% de la capacidad del disco (máximo 2 TB).

Luego se crea una partición exFAT utilizando el espacio restante en el disco (hasta 2 TB) para almacenar juegos y aplicaciones.

## Actualizar el Software del Sistema PS2
Al seleccionar esta opción, se buscan en línea las últimas versiones del **software del sistema PSBBN**, **Paquete de idiomas**, [Canales en línea](#canal-de-internet) y [Menú OSDM](#hosdmenu), y luego instala automáticamente las actualizaciones disponibles. Todos tus juegos, configuraciones y datos personales permanecen intactos.

## Instalar Juegos y Aplicaciones
El **Instalador de juegos** Automatiza completamente la instalación de juegos de PS1 y PS2, así como de aplicaciones caseras:
- Detecta automáticamente tu unidad de PS2
- Para usuarios de Linux, te permite establecer una ruta personalizada en tu PC para almacenar juegos y aplicaciones antes de la instalación
- Ofrece la opción de [sincronizar](#sincronizar-todos-los-juegos-y-aplicaciones) los juegos y aplicaciones de tu PC con el disco de tu PS2, o [agregar](#agregar-juegos-y-aplicaciones-adicionales) juegos y aplicaciones adicionales
- Te da la opción de [Open PS2 Loader (OPL)](#open-ps2-loader-opl) o [NHDDL](#nhddl) para el iniciador del juego.
- Asigna el iniciador de juegos elegido, [POPSLoader](#cargador-de-cop), [R3CONFIGURATOR](#configurador-r3) y [wLaunchELF-R3Z](#lanzamientoelf-r3z) al [botón de inicio](#opciones-de-arranque)
- Instala todas las actualizaciones disponibles para [Open PS2 Loader (OPL)](#open-ps2-loader-opl), [NHDDL](#nhddl), [Neutrino](#nhddl), [POPSLoader](#cargador-de-cop), [wLaunchELF-R3Z](#lanzamientoelf-r3z) y [R3CONFIGURATOR](#configurador-r3)
- Descarga e instala los binarios [POPS](#iniciador-pop) e instala [POPSarter](#iniciador-pop)
- Cuando se selecciona [Open PS2 Loader (OPL)](#open-ps2-loader-opl) como iniciador del juego, ofrece una opción para instalar hacks de pantalla panorámica para juegos de PS2, lo que permite una verdadera compatibilidad con pantalla panorámica 16:9 con un campo de visión más amplio en juegos compatibles.
- Ofrece la opción de aplicar una solución HDTV para juegos de PS1, útil para usuarios con un televisor que no admite 240p
- Convierte automáticamente juegos de PS2 en formato `BIN/CUE` a `ISO` cuando se colocan en la carpeta `CD` de tu PC, y juegos de PS1 en formato `BIN/CUE` a `VCD` cuando se colocan en la carpeta `POPS` de tu computadora
- Cuando se selecciona [Open PS2 Loader (OPL)](#open-ps2-loader-opl) como iniciador del juego, ofrece la opción de comprimir archivos `ISO` a `ZSO`, lo que permite instalar más juegos en su disco.
- Para juegos en el formato `ZSO`, el "Modo de compatibilidad 1" se habilita automáticamente en sus configuraciones [OPL](#open-ps2-loader-opl) por juego.
- Crea [Tarjetas de Memoria Virtuales (VMCs)](#tarjetas-de-memoria-virtuales) para todos los juegos de PS1, con la opción de habilitar VMC para todos los juegos de PS2. También crea [Grupos de VMC](#tarjetas-de-memoria-virtuales) que permite que los juegos compatibles compartan partidas guardadas, desbloqueando funciones y bonificaciones basadas en los juegos que hayas jugado.
- Configura juegos de PS1 multidisco para permitir el intercambio de discos
- Descarga e instala automáticamente [correcciones HugoPocked POPSarter](https://www.psx-place.com/threads/hugopocked-fixes-for-popstarter.39750/), mejorando la compatibilidad con más de 100 juegos de PS1.
- Crea todos los recursos, incluidos metadatos, ilustraciones e íconos para todos tus juegos y aplicaciones:
  - Descarga ilustraciones para PSBBN [Colección de juegos](#colección-de-juegos) de la [Base de datos de arte PSBBN](https://github.com/CosmicScale/psbbn-art-database) o IGN si no se encuentra en la base de datos
  - Contribuye automáticamente con el arte del juego descargado de IGN e informa el arte faltante a la [PSBBN Art Database](https://github.com/CosmicScale/psbbn-art-database)
  - Descarga la portada de los juegos de PS2 y PS1 desde [OPL Manager Art Database](https://oplmanager.com/site/?backups) para mostrarla en [OPL](#open-ps2-loader-opl), [NHDDL](#nhddl) y [POPSLoader](#cargador-de-cop)
  - Descarga iconos para el [Navegador](#hosdmenu) desde [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database). Si los íconos no están disponibles, pero las imágenes de un juego están disponibles en [OPL Manager Art Database](https://oplmanager.com/site/?backups), se crearán íconos 3D automáticamente.
  - Aporta automáticamente íconos HDD-OSD e informa los íconos faltantes al [HDD-OSD Icon Database](https://github.com/cosmicscale/hdd-osd-icon-database)
- Le permite seleccionar qué juegos y aplicaciones caseras desea mostrar en la [Colección de juegos](#colección-de-juegos) y el [Navegador](#hosdmenu).
- Crea **particiones de inicio** que permiten que los juegos y aplicaciones seleccionados instalados en su disco, junto con los juegos de PS1 almacenados en un recurso compartido de red SMB, se inicien desde la [Colección de juegos](#colección-de-juegos) y el [Navegador](#hosdmenu).
- Actualiza accesos directos para aplicaciones caseras en [PSBBN Menu Navigator](#colección-de-juegos) y en [HOSDMenu](#hosdmenu) **menú OSDSYS**
- Habilita BDM HDD, aplicaciones e ilustraciones en el archivo de configuración [OPL](#open-ps2-loader-opl)
- Establece el idioma y la [configuración del botón](#reassign-X-and-Círculo-buttons) en los archivos de configuración [OPL](#open-ps2-loader-opl), [POPSLoader](#cargador-de-cop), [wLaunchELF-R3Z](#lanzamientoelf-r3z) y [R3CONFIGURATOR](#configurador-r3) para que coincidan con la configuración de instalación.

**NOTA:** Para usar archivos `ZSO`, debes seleccionar [OPL](#open-ps2-loader-opl) como iniciador del juego. Cuando se utiliza [NHDDL](#nhddl), cualquier archivo `ZSO` en la carpeta de juegos de su PC o en la unidad de PS2 se descomprime en archivos `ISO`.

### Sincronizar Todos los Juegos y Aplicaciones
Esta opción actualiza el contenido del almacenamiento de tu PS2 para que coincida con el contenido de la carpeta que seleccionaste en tu PC. Todos los juegos o aplicaciones nuevos se copian y los que se eliminaron de su PC se eliminan de la consola.

El script le permite establecer una ruta personalizada en su PC para almacenar los juegos que se instalarán. Simplemente coloque sus archivos en la subcarpeta correcta:
- Los archivos `ISO`, `ZSO` o `BIN/CUE` de PS2 van en la carpeta `CD`
- Los archivos `ISO` o `ZSO` de PS2 en la carpeta `DVD`
- Los archivos `VCD` o `BIN/CUE` de PS1 en la carpeta `DVD` Carpeta <código>POPS`
- Archivos `ELF` o archivos `PSU` [compatibles con SAS](#save-application-system-sas) en la carpeta `APPS`

Para agregar o eliminar juegos y aplicaciones, simplemente modifique el contenido de la carpeta en su PC, luego seleccione **Sincronizar todos los juegos y aplicaciones**.

### Agregar Juegos y Aplicaciones Adicionales
Alternativamente, puedes agregar juegos y aplicaciones caseras directamente al sistema de archivos exFAT en tu unidad PS2 colocando:
- Archivos `ISO` o `ZSO` de PS2 en las carpetas `CD` o `DVD`
- Archivos `VCD` de PS1 en la carpeta `POPS`
- Archivos `ELF` o archivos `PSU` [compatibles con SAS](#save-application-system-sas) en la carpeta `APPS`

Además, se instalarán todos los juegos o aplicaciones nuevos que se encuentren en la carpeta seleccionada de su PC. Al igual que con la sincronización, coloque:
- Los archivos `ISO`, `ZSO` o `BIN/CUE` de PS2 van en la carpeta `CD`
- Los archivos `ISO` o `ZSO` de PS2 en la carpeta `DVD`
- Los archivos `VCD` o `BIN/CUE` de PS1 en el Carpeta <código>POPS`
- Archivos `ELF` o archivos `PSU` [compatibles con SAS](#save-application-system-sas) en la carpeta `APPS`

Al seleccionar **Agregar juegos y aplicaciones adicionales**, se descargan metadatos e ilustraciones de todo el contenido recién agregado.

Los juegos y aplicaciones se pueden eliminar manualmente del sistema de archivos exFAT en la unidad PS2. Al seleccionar **Agregar juegos y aplicaciones adicionales** también se eliminarán los títulos eliminados de la [Colección de juegos](#colección-de-juegos) y el [Navegador](#hosdmenu).

### Save Application System (SAS)
**Save Application System (SAS)** es un nuevo estándar para distribuir aplicaciones caseras para PS2. Todas las aplicaciones compatibles con SAS están empaquetadas en un archivo `PSU` e incluyen íconos y metadatos, lo que la convierte en la forma recomendada de [instalar aplicaciones caseras](#instalar-juegos-y-aplicaciones) en [PSBBN](#psbbn) y [HOSDMenu](#hosdmenu). Puede descargar aplicaciones compatibles con SAS desde la [PS2 Homebrew Store](https://ps2homebrewstore.com/).

### Aplicaciones de Elaboración Casera de ELF
Al instalar aplicaciones en el formato `ELF`, el archivo se compara con una base de datos. Esto permite al instalador recuperar el título, el desarrollador, el ID del título y la categoría de la aplicación, así como descargar automáticamente el arte y el icono apropiados. Para obtener mejores resultados, se recomienda no cambiar el nombre del archivo `ELF`.

### Lanzamiento de Juegos de PS1 Desde SMB
Los juegos de PS1 en formato `.VCD` almacenados en un recurso compartido de red SMB se pueden iniciar desde la [Colección de juegos](#colección-de-juegos) y el [Navegador](#hosdmenu). Antes de ejecutar el instalador del juego:
1. Instala tus juegos de PS1 y los archivos de soporte necesarios en tu dispositivo externo. Las instrucciones se pueden encontrar [aquí](https://nathanneurotic.github.io/POPSTARTERINFO/smb-network.html)
2. Coloque los archivos `POPSTARTER.ELF` renombrados con el prefijo `SB.` en la carpeta `POPS`, ya sea en su PC o directamente en la unidad de su PS2.

### Selector de Juegos
Al ejecutar el instalador de juegos, se le presentará una lista de todos los juegos y aplicaciones instalados, lo que le permitirá elegir qué títulos aparecen en la [Colección de juegos](#colección-de-juegos) y el [Navegador](#hosdmenu). Si tiene una colección grande, limitar la cantidad de títulos mostrados puede mejorar su experiencia de navegación.

Se pueden mostrar hasta 800 títulos en la [Colección de juegos](#colección-de-juegos) y el [Navegador](#hosdmenu). Todos los juegos de PS2 seguirán disponibles en el iniciador de juegos elegido ([OPL](#open-ps2-loader-opl) o [NHDDL](#nhddl)), y todos los juegos de PS1 seguirán disponibles en [POPSLoader](#cargador-de-cop). Todas las aplicaciones permanecerán disponibles en [OPL](#open-ps2-loader-opl) y [HOSDMenu's](#hosdmenu) **Menú OSDSYS**.

También puedes personalizar el orden en que aparecen las categorías, como Juegos de PS2, Juegos de PS1, Iniciadores y Aplicaciones, lo que te brinda control total sobre cómo está organizada tu biblioteca.

### InstalaÃ§Ã£o dos drivers ATA BDM Assault
Para iniciar juegos de PS1 desde la [Colección de juegos](#colección-de-juegos) o el [Navegador](#hosdmenu), primero debes instalar los **controladores ATA BDM Assault** en una tarjeta de memoria de PS2.

1. Inserta una tarjeta de memoria PS2 en tu consola PS2.
2. Inicie [POPSLoader](#cargador-de-cop).
3. Inicie cualquier juego de PS1.

Los controladores necesarios se instalarán automáticamente en la tarjeta de memoria de PS2.

## Instalar Medios
**NOTA: Estas Funciones Son Solo para Usuarios de PSBBN.**  

Seleccione **Instalar medios** en Menú Principal y se le presentará la siguiente opción:
1. [Instalar música](#instalar-música)
2. [Instalar películas](#instalar-películas)
3. [Instalar fotos](#instalar-fotos)
4. [Establecer ubicación de medios](#establecer-ubicación-de-medios)
5. [Inicializar partición de música](#inicializar-partición-de-música)

### Instalar Música
Instale música para reproducirla en el [Canal de música PSBBN] (#canal-de-música). Para utilizar el instalador de música, debe ejecutar **PSBBN Definitive Patch versión 3.00 o posterior**. Si ya actualizó desde una versión anterior, primero debe [Inicializar la partición de música](#inicializar-partición-de-música).

Los formatos admitidos son `.mp3`, `.m4a`, `.flac` y `.ogg`. Los metadatos de cada archivo deben incluir el título del álbum y el número de pista. Coloque sus archivos de música en la carpeta `music` predeterminada de su PC, o elija una ubicación personalizada usando [Establecer ubicación de medios](#establecer-ubicación-de-medios) y coloque los archivos en la subcarpeta `music`.

### Instalar Películas
Instale videos para reproducirlos en el [Canal de películas PSBBN] (#canal-de-peliculas). Para utilizar Movie Installer, debe ejecutar **PSBBN Definitive Patch versión 3.00 o posterior**. Su PC también debe tener un procesador x86.

Movie Installer admite `MP4`, `M4V`, `MKV`, `VOB` y otros formatos populares, así como los formatos de vídeo de PlayStation 2 `pss` y `psm`. Los vídeos más cortos están codificados con una tasa de bits más alta que los vídeos más largos. Debes limitar la duración del vídeo a 2 horas y 15 minutos; Los vídeos más largos pueden codificarse mal o no poder convertirse.

Coloque sus archivos de video en la carpeta `movie` predeterminada de su PC, o elija una ubicación personalizada usando [Establecer ubicación de medios](#establecer-ubicación-de-medios) y coloque los archivos en la subcarpeta `movie`.

### Instalar Fotos
Instale imágenes para verlas en el [Canal de fotos PSBBN] (#canal-de-fotos). Para utilizar Photo Installer, debe ejecutar **PSBBN Definitive Patch versión 3.00 o posterior**.

Formatos admitidos, incluidos `JPG`, `PNG`, `TIF`, `GIF`, `BMP` y más. Coloque sus archivos de imagen en la carpeta `photo` predeterminada de su PC, o elija una ubicación personalizada usando [Establecer ubicación de medios](#establecer-ubicación-de-medios) y coloque los archivos en la subcarpeta `photo`.

### Establecer Ubicación de Medios
Establezca una ubicación personalizada para su carpeta `media`. La música debe colocarse en una subcarpeta `music`, los vídeos deben colocarse en una subcarpeta `movie` y las imágenes deben colocarse en una subcarpeta `photo`.

### Inicializar Partición de Música
Esta opción borra todos los datos de música y restablece la base de datos de música utilizada por el [Canal de música PSBBN] (#canal-de-música). Utilice esta opción si ha actualizado desde una versión de **PSBBN Definitive Patch** inferior a 3.0 y desea utilizar el [Instalador de música](#instalar-música). También puede utilizar esta opción si tiene problemas con el [Canal de Música] (#canal-de-música).

## Extras Opcionales
Seleccione **Extras opcionales** de Menú Principal y se le presentará la siguiente opción:
1. [Instalar PS2 Linux](#instalar-ps2-linux)
2. [Reasignar botones en forma de cruz y círculo](#reassign-X-and-Círculo-buttons)
3. [Cambiar idioma](#cambiar-idioma)
4. [Cambiar configuración de pantalla](#cambiar-la-configuración-de-la-pantalla)
5. [Borrar caché de iconos y arte](#borrar-caché-de-arte-e-íconos)

### Instalar PS2 Linux
**NOTA: Esta Función Es Solo para Usuarios de PSBBN.**  

PlayStation 2 Linux es un kit oficial de Sony que convirtió la PS2 en una computadora personal basada en Linux.
La opción **Instalar PS2 Linux** le permite instalar o reinstalar PS2 Linux.

Para utilizar esta función, debe:
- Reserve al menos 3 GB de espacio durante la [instalación de PSBBN](#instale-psbbn-y-hosdmenu).
- Tener instalada la versión 4.0.0 o posterior de PSBBN Definitive Project.

Al reinstalar PS2 Linux:
- Si Linux vino preinstalado con su versión de PSBBN Definitive Project, se borrarán todos los datos de PS2 Linux, incluido su directorio de inicio.
- Si instaló o reinstaló Linux usando la opción **Instalar PS2 Linux**, solo se reinstalarán los archivos del sistema; sus archivos personales en el directorio de inicio no se verán afectados.

Al instalar PS2 Linux por primera vez, o al reinstalar una versión que venía preinstalada con PSBBN Definitive Project, se le pedirá que elija el tamaño de su directorio de inicio. El directorio de inicio es donde se almacenan sus archivos y aplicaciones personales.

**Notas:**  
- Para iniciar PS2 Linux, encienda su consola PS2 y luego mantenga presionado el botón ○ en el controlador. Entonces arrancará PS2 Linux.
- PS2 Linux requiere un teclado USB; un mouse es opcional pero recomendado.
- Las cuentas de usuario `root` y `ps2` están configuradas con la contraseña predeterminada `password`.
- Para iniciar una interfaz gráfica, escriba `startx` en la línea de comando.
- Al iniciar el navegador web **Dillo** se abrirá un espejo del antiguo sitio web oficial de PS2 Linux, donde podrás encontrar una amplia gama de software para descargar y probar.

### Reasignar Botones de Cruz y Círculo
Esta opción le permite intercambiar las funciones de los botones × y ○ en su controlador. Puede elegir entre el diseño estándar (× = Confirmar, ○ = volver) o el diseño alternativo (○ = Confirmar, × = volver), según su preferencia.

**NOTA: Esta Función Solo Se Aplica a [PSBBN](#psbbn), [OPL](#open-ps2-loader-opl), [WLaunchELF-R3Z](#lanzamientoelf-r3z) y [R3CONFIGURATOR](#configurador-r3). no Cambia el Diseño del Botón para el Cuadro de Diálogo [POPS](#iniciador-pop) in-Game Reset al Salir de un Juego de PS1, o [HOSDMenu](#hosdmenu).**  

### Cambiar Idioma
Cuando se instala [PSBBN](#psbbn), esta opción cambia el idioma del sistema de PSBBN. Seleccione entre inglés, alemán, italiano, portugués brasileño, español, francés, húngaro y japonés original. Se agregarán más idiomas con futuras actualizaciones. Para los usuarios japoneses, también descarga e instala las versiones japonesas de los [Canales en línea] (#canal-de-internet).

Para los usuarios de [PSBBN](#psbbn) y [HOSDMenu](#hosdmenu), esta opción también cambia el idioma de [OPL](#open-ps2-loader-opl), [wLaunchELF-R3Z](#lanzamientoelf-r3z), [R3CONFIGURATOR](#configurador-r3), [POPSLoader](#cargador-de-cop) y el mensaje [POPS](#iniciador-pop) In-Game Reset (IGR), así como la preferencia de idioma utilizada por el [Instalador del juego](#instalar-juegos-y-aplicaciones).

Después de cambiar el idioma, se recomienda volver a ejecutar el [Instalador de juegos](#instalar-juegos-y-aplicaciones) y seleccionar *Agregar juegos y aplicaciones adicionales* para actualizar los títulos de los juegos al idioma seleccionado (solo inglés y japonés). Para los usuarios de [PSBBN](#psbbn), esto también actualizará los manuales de los juegos de PlayStation.

### Cambiar la Configuración de la Pantalla
**NOTA: Esta Función Es Solo para PSBBN.**  
[PSBBN](#psbbn) normalmente bloquea la configuración del sistema de pantalla en **4:3**. Esta opción le permite cambiar la configuración de la pantalla. Puede elegir entre **4:3**, **Completo** y **16:9**.

Esta configuración la utilizan algunos juegos y [HOSDMenu](#hosdmenu). No cambia la relación de aspecto de [PSBBN](#psbbn) en sí.

### Borrar Caché de Arte e Íconos
Esta opción elimina todas las ilustraciones y los íconos del juego que están almacenados localmente en su PC. La próxima vez que ejecutes el instalador del juego, escaneará tu colección de juegos, luego descargará y aplicará copias nuevas de las ilustraciones y los íconos necesarios.

Es posible que desees borrar el caché si los juegos muestran ilustraciones incorrectas o de baja calidad, ya que es posible que ahora haya ilustraciones actualizadas disponibles.

# Guía del Usuario

## Opciones de Arranque
Puedes mantener presionados los botones del controlador mientras enciendes la consola PS2 para cambiar cómo se inicia el sistema:

| Botón | Software del sistema PS2 | Comportamiento de arranque |
|--------|---------------------|----------------------------------------------------|
| Ninguno | PSBBN + HOSDMenu | Arranca automáticamente [PSBBN](#psbbn) |
| Ninguno | Solo HOSDMenu | Arranca automáticamente [HOSDMenu](#hosdmenu) |
| ✕ | PSBBN + HOSDMenu | Botas [HOSDMenu](#hosdmenu) |
| ○ | PSBBN + HOSDMenu | Arranca [PS2 Linux](#instalar-ps2-linux) (si está instalado) |
| □ | Cualquier configuración | Inicia el iniciador del juego seleccionado ([OPL](#open-ps2-loader-opl) o [NHDDL](#nhddl)) |
| △ | Cualquier configuración | Botas [POPSLoader](#cargador-de-cop) |
| START | Cualquier configuración | Botas [wLaunchELF-R3Z](#lanzamientoelf-r3z) |
| SELECT | Cualquier configuración | Botas [R3CONFIGURADOR](#configurador-r3) |

## PSBBN
PlayStation Broadband Navigator (también conocido como BB Navigator y PSBBN) es un sistema operativo oficial de PlayStation 2 lanzado exclusivamente en Japón. Cuenta con canales para [juegos](#colección-de-juegos), [música](#canal-de-música), [películas](#canal-de-peliculas), [fotos](#canal-de-fotos) y [servicios de Internet](#canal-de-internet).

El **Parche Definitivo** mejora y amplía su funcionalidad, ofreciendo:
- Una traducción completa de la versión 0.32 del software BB Navigator japonés: todos los binarios, archivos XML, texturas e imágenes han sido traducidos[*](#problemas-conocidos)
- Disponible en inglés, alemán, italiano, portugués brasileño, español, francés, húngaro y japonés original
- Compatibilidad con consolas PS2 de todas las regiones; el software original estaba restringido a las consolas japonesas
- [OSDMenu MBR](#osdmenu-mbr): un reemplazo casero del programa MBR original de Sony con numerosas mejoras con respecto a la implementación original
- Un `osdboot.elf` parcheado para evitar el control de seguridad CRC, permitiendo el uso de kernels personalizados
- Compatibilidad con discos duros grandes: originalmente limitado a 128 GB. Ahora se admiten unidades de hasta 2 TB mediante [APA-Jail](#apa-jail)
- Una partición de música de hasta 114 GB para alrededor de 180 álbumes[*](#problemas-conocidos); originalmente limitado a 5 GB
- Una partición de contenidos de hasta 114 GB para el almacenamiento de películas y fotografías; originalmente limitado a 5 GB
- Un enlace directo a la [Colección de juegos](#colección-de-juegos) en el **Menú superior** para un acceso rápido
- Se omiten las comprobaciones de autorización de DNAS para permitir el acceso a los [canales en línea](#canal-de-internet)
- [Canales en línea](#canal-de-internet) de Sony, Hudson, EA, Konami, Capcom, Namco, KOEI, Bandai, So-Net y BIGLOBE
- Japonés original [canales en línea](#canal-de-internet) en japonés en instalaciones japonesas y en inglés en todas las demás instalaciones
- Función **Reproductor de audio** agregada nuevamente al [Canal de música](#canal-de-música) desde una versión anterior de PSBBN, lo que permite compatibilidad con grabadoras MiniDisc NetMD[*](#problemas-conocidos)
- Páginas de manual y solución de problemas relacionadas con la función **Reproductor de audio** agregadas nuevamente a la guía del usuario
- Teclado en pantalla QWERTY japonés reemplazado por teclado en pantalla en inglés estadounidense[*](#problemas-conocidos)
- Una opción para intercambiar las funciones de los botones × y ○
- Una opción para cambiar la configuración de la pantalla (normalmente bloqueada 4:3), con modos seleccionables: 4:3, Completo y 16:9.
- Soporte para el control remoto del DVD de PlayStation 2[*](#problemas-conocidos)

Para obtener detalles completos sobre todas las funciones y una guía de usuario completa, consulta la **Guía de PlayStation BB**, accesible desde el **Menú superior**.

### Colección de Juegos
Puedes encontrar la **Colección de juegos** en PSBBN **Menú superior**. Este es el primer menú que ve cuando se inicia PSBBN.
- Cuando se instala usando el [Instalador de juegos](#instalar-juegos-y-aplicaciones), todas las [aplicaciones y juegos seleccionados](#selector-de-juegos) se mostrarán en la colección usando una interfaz de estilo de portada.
- Los juegos se dividen en Juegos de PS2 y Juegos de PS1.
- Los juegos están ordenados alfabéticamente y por series, con las entradas dentro de cada serie ordenadas por fecha de lanzamiento.
- Cuando el idioma está configurado en japonés, los títulos de juegos de la región japonesa se muestran en su japonés original y se ordenan en orden “gojūon” (五十音).
- Las aplicaciones Homebrew se dividen en las siguientes categorías: emuladores, juegos, demostraciones, aplicaciones, aplicaciones de PS1, aplicaciones de sistema, herramientas de diagnóstico, aplicaciones de depuración y entornos de ejecución.
- Puede ver un manual para juegos de PS1 que enumera las [teclas de acceso rápido] compatibles (#iniciador-pop). Para acceder al manual, presione **△** en un juego de PS1 resaltado y seleccione *Manual*.
- Puedes configurar atajos para hasta cuatro elementos presionando **△** en un juego resaltado y seleccionando *Agregar a Menu Navigator*. Puede acceder rápidamente a sus accesos directos presionando **SELECT**.

### Canal de Música
El **Canal de Música** te permite reproducir CD de audio, escuchar música almacenada en el disco interno de tu PS2 y crear listas de reproducción personalizadas. La música se puede copiar directamente en la PS2 desde un CD de audio e instalarla usando el [Instalador de música] (#instalar-música).

También admite la exportación de música a una grabadora MiniDisc compatible con NetMD. Sin embargo, la compatibilidad con MiniDisc no funciona en la versión actual de PSBBN Definitive Patch. Si desea probar la funcionalidad MiniDisc, puede utilizar una [versión antigua del parche en inglés definitivo PSBBN](https://github.com/CosmicScale/PSBBN-Definitive-Project/tree/PSBBN-Definitive-English-Patch).

### Canal de Peliculas
**Movie Channel** te permite reproducir películas almacenadas en el disco interno de tu PS2, organizarlas y crear listas de reproducción. Las películas se pueden descargar desde varios de los [Canales en línea] (#canal-de-internet) e instalarlas usando el [Instalador de películas] (#instalar-películas).

### Canal de Fotos
Photo Channel te permite ver fotos almacenadas en la unidad interna de la PS2 o en un dispositivo USB con formato FAT (memoria USB, cámara digital, etc.). Las fotos se pueden importar desde dispositivos USB e instalar usando [Photo Installer] (#instalar-fotos). Puedes crear álbumes y listas de reproducción de tus fotos. También puedes descargar ilustraciones y capturas de pantalla del juego desde los [Canales en línea] (#canal-de-internet).

### Canal de Internet
En el **Canal de Internet**, puede acceder a archivos de los canales en línea de varios editores, tal como aparecían a principios de la década de 2000. Los canales han sido traducidos al inglés (trabajo en progreso). Si tiene una instalación japonesa de PSBBN, tendrá acceso a las versiones japonesas originales. Para ver estos canales en línea, su sistema PlayStation 2 debe estar conectado a Internet. En el **Canal de Internet** puedes:
- Explorar los canales en línea de varios editores de juegos, incluidos Sony, Hudson, EA, Konami, Capcom, Namco, KOEI y Bandai.
- Descarga avances de *Metal Gear Solid 3: Subsistence*, *Bomberman Online* y más. Los avances se pueden descargar desde **Konami Channel**, **BANDAI Entertainment World** y **HUDSON CHANNEL**. Los avances descargados se guardan en un álbum en el [Canal de películas] (#canal-de-peliculas).
- Descarga ilustraciones y capturas de pantalla del canal **PlayStation® Now!**. Las imágenes descargadas se guardan en un álbum en el [Canal de fotos] (#canal-de-fotos).
- Juega una serie de juegos clásicos del archivo de Hudson, incluidos *Star Soldier*, *Milon's Secret Castle* y *Nuts & Milk*. Los juegos se pueden jugar seleccionando *JUGAR JUEGOS* en el **CANAL HUDSON** Menú Principal.

## HOSDMenu
**HDD-OSD** es el software oficial de Sony que amplía el menú del sistema de PlayStation 2 (OSDSYS) con soporte para disco duro, lo que le permite administrar software, guardar datos e iniciar juegos y aplicaciones directamente desde el disco duro a través del navegador 2.0. **HOSDMenu**, escrito por [pcm720](https://github.com/pcm720), parchea **HDD-OSD** y agrega características adicionales, que incluyen:
- Compatibilidad con unidades más grandes: **HDD-OSD** se limitaba anteriormente a 1 TB
- Inicie aplicaciones caseras directamente desde el menú personalizado **OSDSYS**
- Inicie [aplicaciones compatibles con SAS](#save-application-system-sas) desde tarjetas de memoria y desde la unidad interna en **Browser 2.0**
- Soporte para iniciar aplicaciones desde dispositivos MMCE, MX4SIO, UDPBD, iLink y discos duros con formato APA y exFAT
- [Inicie discos de juegos de PS1 y PS2](#lanzamiento-de-discos-de-juegos-de-ps1-y-ps2) con soporte para Game ID, MechaPwn y PS1VmodeNeg integrado
- GSM integrado para juegos y aplicaciones en disco
- Soporte para 1080i y 480p
- Y más: consulte el [repositorio de GitHub](https://github.com/pcm720/OSDMenu) para obtener todos los detalles.

Si se instala junto con [PSBBN](#psbbn), se puede iniciar desde la [Colección de juegos](#colección-de-juegos), a través de un [atajo en Menu Navigator](#colección-de-juegos), o manteniendo presionado el botón × mientras se inicia la consola. Si solo se instaló **HOSDMenu**, se iniciará automáticamente.

Cuando se instala con el [Instalador del juego](#instalar-juegos-y-aplicaciones):
- Todas las aplicaciones aparecerán en el **menú OSDSYS**, lo que permitirá un inicio rápido
- [aplicaciones y juegos seleccionados](#selector-de-juegos) aparecerán en el **Navegador**. Los juegos se mostrarán como íconos 3D únicos modelados en sus estuches físicos de DVD/CD, obtenidos de [HDD-OSD Icon Database](https://github.com/CosmicScale/HDD-OSD-Icon-Database)
- Las [aplicaciones compatibles con SAS](#save-application-system-sas) descargadas de la [PS2 Homebrew Store](https://ps2homebrewstore.com/) y los archivos `ELF` también aparecerán en el **Navegador** representados por íconos únicos.

## Open PS2 Loader (OPL)
[Open PS2 Loader (OPL)](https://github.com/ps2homebrew/Open-PS2-Loader) es un cargador de aplicaciones y juegos 100% de código abierto para PS2. Todos los juegos de PS2 instalados se mostrarán en OPL. Si selecciona OPL como iniciador de juegos al [instalar juegos y aplicaciones](#instalar-juegos-y-aplicaciones), la configuración por juego asignada en OPL se reflejará al iniciar juegos desde la [Colección de juegos](#colección-de-juegos) y el [Navegador](#hosdmenu).

## NHDDL
[NHDDL](https://github.com/pcm720/nhddl) es un lanzador para [Neutrino](https://github.com/rickgaiser/neutrino), un emulador de dispositivo PS2 pequeño, rápido y modular. Todos los juegos de PS2 instalados se mostrarán en NHDDL. Si selecciona NHDDL como iniciador de juegos al [instalar juegos y aplicaciones](#instalar-juegos-y-aplicaciones), la configuración por juego asignada en NHDDL se refleja al iniciar juegos desde la [Colección de juegos](#colección-de-juegos) y el [Navegador](#hosdmenu).

## Cargador de COP
[POPSLoader](https://github.com/NathanNeurotic/POPSLoader) es un iniciador gráfico diseñado para explorar e iniciar fácilmente tus juegos de PS1 (usando [POPSarter](#iniciador-pop)) desde varios dispositivos de almacenamiento. Todos los juegos de PS1 instalados se mostrarán en **POPSLoader**.

## Iniciador POP
**POPS** es un emulador oficial de Sony PS1 para PS2, lanzado originalmente exclusivamente en Japón como una forma de distribuir juegos de PS1 a través de Internet a usuarios de [PSBBN](#psbbn). **POPSarter** es un iniciador casero para **POPS** que permite al emulador jugar cualquier juego de PS1 desde unidades internas y externas.

Al instalar juegos de PS1, **[correcciones de HugoPocked POPSarter](https://www.psx-place.com/threads/hugopocked-fixes-for-popstarter.39750/)** se descargan e instalan automáticamente, lo que mejora la compatibilidad con más de 100 juegos de PS1.

Se admiten combinaciones de botones de acceso rápido para el intercambio de discos y varias otras opciones:

| Tecla de acceso rápido | Función |
|----------------------|--------------------------------|
| SELECT + START + L1 | Salir del juego |
| SELECT + L2 + R2 + ✕ | Restablecimiento de software |
| SELECT + L1 + R2 | Habilitar mapeo de textura suave |
| SELECT + L2 + R1 | Deshabilitar el mapeo de textura suave |
| SELECT + R1 + R2 | Habilitar líneas de exploración |
| SELECT + L1 + L2 | Deshabilitar líneas de exploración |
| SELECT + L2 + R2 + △ | Abra la tapa del CD de PlayStation |
| SELECT + L2 + R2 + ↑ | Insertar disco 1 |
| SELECT + L2 + R2 + → | Insertar disco 2 |
| SELECT + L2 + R2 + ↓ | Insertar disco 3 |
| SELECT + L2 + R2 + ← | Insertar disco 4 |
| SELECT + L2 + R2 + □ | Cerrar la tapa del CD de PlayStation |

Los detalles sobre las teclas de acceso rápido también se pueden encontrar en el **Manual** de cada juego de PS1 instalado. Para acceder a él, en **[Colección de juegos](#colección-de-juegos)**, presiona **△** y luego selecciona **Manual**.

## Salir de Juegos
Se admiten combinaciones de botones de acceso rápido para salir de juegos y apagar la consola.

**NOTA: Si Seleccionó [NHDDL](#nhddl) Como Iniciador de Juegos, no Podrá Realizar Estas Funciones Mientras Juega Juegos de PS2.**

| Tecla de acceso rápido | Función |
|------------------------------------|------------------------------------|
| SELECT + START + L1 | Salir del juego de PS1 |
| L1 + L2 + R1 + R2 + SELECT + START | Salir de los juegos de PS2 |
| L1 + L2 + L3 + R1 + R2 + R3 | Apagar la consola (solo juegos de PS2) |

## Tarjetas de Memoria Virtuales
Una **Tarjeta de Memoria Virtual (VMC)** te permite almacenar el progreso del juego en la unidad interna de tu PlayStation 2 en lugar de en una tarjeta de memoria estándar.

Se crea un **POPStarter VMC** para cada juego de PS1 y, cuando ejecutes el [Instalador de juegos](#instalar-juegos-y-aplicaciones), tendrás la opción de habilitar **VMC** para todos tus juegos de PS2.

Tanto los juegos de PS1 como los de PS2 son compatibles con **Grupos de VMC**, lo que permite que ciertos juegos compartan un VMC y accedan a datos guardados creados por otros títulos. Por ejemplo, Psycho Mantis de *Metal Gear Solid* puede comentar sobre otros juegos de Konami que hayas jugado, y los créditos de *Gran Turismo 3* se pueden transferir a *Gran Turismo 4*.

## ID del Juego
La función Game ID en **Retro GEM**, **MemCard Pro 2** y **SD2PSX** es totalmente compatible al iniciar juegos y aplicaciones caseras desde la [Colección de juegos](#colección-de-juegos) y el [Navegador](#hosdmenu), así como desde discos físicos de juegos de PS1 y PS2.

**Retro GEM** es una actualización de salida HDMI digital a digital para múltiples consolas. **Retro GEM Game ID** permite el cambio automático de perfiles de visualización por juego. Puede obtener más información sobre **Retro GEM** en el [sitio web de Pixel FX](https://www.pixelfx.co/hdmi-retro-gem).

**MemCard Pro 2** y **SD2PSX** permiten almacenar datos guardados en una tarjeta SD, lo que admite múltiples **Tarjetas de Memoria Virtuales (VMCs)** y muchas otras funciones. El **Game ID** identifica qué juego se está ejecutando, lo que permite asignar a cada juego su propio **VMC** y cambiar automáticamente a la tarjeta correcta cuando se inicia el juego. Puede obtener más información sobre **MemCard Pro 2** en el [sitio web de 8BitMods](https://8bitmods.com/accessories/memcard-pro/) y sobre **SD2PSX** en el [sitio web de SD2PSX](https://sd2psx.net/)

## Lanzamiento de Discos de Juegos de PS1 y PS2
Cuando ejecute [PSBBN](#psbbn) o [HOSDMenu](#hosdmenu), simplemente inserte un disco de juego en la unidad de DVD. El juego se iniciará y configurará el [ID del juego](#id-del-juego) tanto en **Retro GEM** como en **MemCard Pro** o **SD2PSX** según corresponda.

[MechaPwn](https://github.com/MechaResearch/MechaPwn) también es totalmente compatible, con parches automáticos del logotipo de PS2 que permiten iniciar discos maestros e importados sin omitir el logotipo de PlayStation 2 ni encontrar una pantalla con el logotipo dañado. Al reproducir juegos importados de PS1, el modo de vídeo del controlador de PlayStation se ajusta si es necesario para garantizar que se ejecuten en el modo de vídeo correcto.

## LanzamientoELF-R3Z
Una bifurcación de [wLaunchELF](https://github.com/ps2homebrew/wLaunchELF) de [R3Z3N](https://github.com/saildot4k) que incluye varias funciones avanzadas. En particular, le permite administrar archivos en la partición exFAT del disco interno, una capacidad que no está disponible en otras bifurcaciones de wLaunchELF. Más información está disponible [aquí](https://github.com/saildot4k/wLaunchELF_R3Z).

## CONFIGURADOR R3
Una aplicación GUI para editar [OSDMenu](osdmenu-mbr) y otros archivos de configuración. Le permite modificar las opciones de inicio, como asignar una aplicación a un botón para un inicio rápido al inicio, configurar los modos de visualización para [HOSDMenu](#hosdmenu), habilitar o deshabilitar el menú personalizado [HOSDMenu](#hosdmenu) **OSDSYS** y mucho más.

Puede encontrar todos los detalles en la [página GitHub de R3CONFIGURATOR](https://github.com/saildot4k/R3CONFIGURATOR).

## OSDMenu MBR
**OSDMenu MBR** es un componente principal de **PSBBN Definitive Project**. Escrito por [pcm720](https://github.com/pcm720). Este programa se ejecuta en cada inicio del sistema y cuando se inicia una aplicación desde [PSBBN](#psbbn). Es un reemplazo casero del programa MBR original de Sony. Es responsable de inicializar el hardware, así como de iniciar aplicaciones y discos de juegos.

**OSDMenu MBR** viene con muchas ventajas sobre la implementación original, incluida la compatibilidad con el lanzamiento de ELF manteniendo presionado un botón del gamepad al inicio, parcheo automático del logotipo de PS2 al [iniciar discos de juegos de PS2](#lanzamiento-de-discos-de-juegos-de-ps1-y-ps2), ajuste de modos de video al [iniciar discos de juegos de PS1 importados](#lanzamiento-de-discos-de-juegos-de-ps1-y-ps2), [Visual Game ID](#id-del-juego) para **Retro GEM**, sistema de modificación configuraciones e iniciar aplicaciones y juegos caseros a través de [OPL](#open-ps2-loader-opl), [NHDDL](#nhddl) y [POPSarter](#iniciador-pop).

El README completo se puede encontrar [aquí](https://github.com/pcm720/OSDMenu/blob/main/mbr/README.md).

## APA-Jail
![APA-Jail Tipo-A2](https://github.com/user-attachments/assets/8c83dab7-f49f-4a77-b641-9f63d92c85e7)

**APA-Jail** es otro componente central de **PSBBN Definitive Project**. [PSBBN](#psbbn) originalmente estaba limitado a solo 128 GB de almacenamiento utilizable. **APA-Jail** permite poco más de 2 TB.

**APA-Jail**, creado y desarrollado por [Berion](https://www.psx-place.com/resources/authors/berion.1431/), permite que las particiones APA de la PS2 coexistan con una partición exFAT. Para [PSBBN](#psbbn), se pueden reservar hasta 128 GB de la unidad para particiones APA, mientras que el espacio restante (hasta 2 TB) se formatea como exFAT. Esta configuración permite instalar [PSBBN](#psbbn) y [HOSDMenu](#hosdmenu) en las particiones APA, mientras que los juegos y aplicaciones caseras se instalan en la partición exFAT.

[OSDMenu MBR](#osdmenu-mbr) reside en una partición APA especial. Cuando se selecciona un elemento de la [Colección de juegos](#colección-de-juegos), [OSDMenu MBR](#osdmenu-mbr) carga juegos y aplicaciones caseras desde la partición exFAT. Los juegos de PS1 se manejan a través de [POPSarter](#iniciador-pop) y los juegos de PS2 a través de [OPL](#open-ps2-loader-opl) o [NHDDL](#nhddl).

**Advertencia: la Creación Manual de Nuevas Particiones APA en su Unidad PS2 y Exceder el Espacio Asignado para APA Dañará la Unidad.**

## Consolas Anteriores (SCPH-10000–18000) y Delgadas (SCPH-700xx)
**PSBBN Definitive Project** se puede instalar en los modelos PS2 Slim **SCPH-700xx** con un [IDE Resurrector](https://gusse.in/shop/ps2-modding-parts/ide-resurrector-origami-v0-7-flex-cable-for-ps2-slim-spch700xx/) o un mod de hardware similar. La instalación en una tarjeta SD no es compatible con Windows. Para compatibilidad con PSBBN, se debe utilizar un adaptador SATA, como el [iFlash-Sata v10](https://www.iflash.xyz/store/iflash-sata-v10/).

También debe descargar los [Controladores de disco duro externos] (https://israpps.github.io/FreeMcBoot-Installer/test/8_Downloads.html). Extraiga los archivos y coloque `hddload.irx`, `dev9.irx` y `atad.irx` en la carpeta del sistema apropiada para su región en una **tarjeta de memoria oficial de Sony PS2**:

| Región | Nombre de la carpeta |
|----------|-------------- |
| japonés | SISTEMA BIEXEC |
| americano | SISTEMA BAEXEC |
| Asiático | SISTEMA BAEXEC |
| europeo | SISTEMA BEEXEC |
| Chino | SISTEMA BCEXEC |

Los modelos **SCPH-10000 a SCPH-18000** con una carcasa de disco duro externa oficial no tienen la capacidad de iniciarse automáticamente sin software adicional. Para iniciar PSBBN, se recomienda utilizar **PlayStation 2 Basic Boot Loader (PS2BBL)**. [Instala PS2BBL como actualización del sistema](https://israpps.github.io/PlayStation2-Basic-BootLoader/Downloads/) en tu tarjeta de memoria PS2. En el archivo de configuración, establezca `LK_AUTO_E1` en `hdd0:/__system/p2lboot/osdboot.elf`.

# Solución de Problemas
⚠️ **Problema conocido**: La instalación en **Fedora** es actualmente problemática. Se recomienda utilizar una distribución **basada en Debian** o **[PSBBN Launcher for Windows](#instalación-en-windows)**.

1. Asegúrese de estar ejecutando la última versión de su sistema operativo y de que todas las actualizaciones disponibles estén instaladas
2. Utilice un sistema operativo recomendado. **PSBBN Definitive Project** se ha probado completamente en:
- Debian
- Linux Mint
- Raspberry Pi OS
- Windows 10 Home Edition
- Windows 11 Home Edition

## Problemas al Ejecutar el Script

**Si Recibe el Error "Error al Crear la Lista de Juegos":**

Es probable que el archivo `ISO`, `ZSO` o `VCD` que se está procesando no sea válido o esté dañado. Elimine el archivo tanto de la carpeta local de su PC como de su unidad PS2, luego inténtelo nuevamente.

Para evitar este problema, asegúrese de que la imagen de su juego sea un buen volcado verificado. Verifique la suma de verificación MD5 o SHA-1 de su archivo `ISO` o `BIN` y confirme que coincida con la entrada correspondiente en [redump.org](http://redump.org).

**Si Está Utilizando [Windows](#instalación-en-windows) y Tiene Problemas:**

Si el [menú PSBBN Definitive Project](#menú-principal) muestra cuadrados en lugar de texto, o el [menú selector de juegos](#selector-de-juegos) no se muestra correctamente, cambie la fuente de PowerShell. Haga clic derecho en la barra de título de PowerShell, abra **Propiedades** y seleccione **Cascadia Mono** (Windows 11) o **MS Gothic** (Windows 10).

Para otros problemas, continúe con los pasos de solución de problemas a continuación:

1. Abra PowerShell como administrador y ejecute el siguiente comando:
```
wsl --unregister PSBBN
```
2. Descargue la última versión del script `PSBBN-Launcher-For-Windows.ps1` [aquí](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch/releases/download/latest/PSBBN-Launcher-For-Windows.ps1)
3. Asegúrese de tener una conexión a Internet activa. Si está utilizando una VPN, intente deshabilitarla
4. Ejecute el script `PSBBN-Launcher-For-Windows.ps1` nuevamente

**Si Está Utilizando [Linux](#instalación-en-linux) y Tiene Problemas:**
1. Elimine la carpeta `PSBBN-Definitive-Project`
2. Vuelva a clonar el repositorio con el siguiente comando:
```
git clone https://github.com/CosmicScale/PSBBN-Definitive-Project.git
```

**¿Aún Tienes Problemas?**
1. Intente conectar la unidad PS2 directamente a su PC mediante una conexión SATA interna o un puerto USB directamente en la placa base. Evite el uso de tarjetas adicionales
2. Si está utilizando un adaptador SATA a USB, intente usar una marca o modelo diferente
3. Si aún tiene problemas, pruebe con una unidad diferente

## Problemas al Iniciar PSBBN y HOSDMenu
Cuando conectas la unidad a tu consola PS2 y la enciendes, **[PSBBN o HOSDMenu](#opciones-de-arranque)** debería iniciarse automáticamente.

Si su consola arranca en el OSD normal, se congela o muestra un error, debe intentar lo siguiente:
1. Retire todas las tarjetas de memoria PS2 de su consola
2. Si instaló [PSBBN](#psbbn), asegúrese de estar utilizando un **adaptador de red oficial de Sony**; PSBBN no admite adaptadores HDD de terceros
3. Verifique que los conectores de la consola y la red o el adaptador HDD estén limpios y libres de polvo/residuos
4. Asegúrese de que la red o el adaptador HDD y la unidad estén bien conectados a la consola
5. Si usa un mod SATA, asegúrese de que se haya instalado correctamente
6. Utilice una unidad diferente y reinstale [PSBBN](#instale-psbbn-y-hosdmenu) o [HOSDMenu](#instalar-hosdmenu-únicamente)
7. Si su consola tiene instalado un convertidor IDE o un mod SATA, intente usar un convertidor o mod diferente.
8. Utilice un adaptador de red oficial de Sony diferente o un adaptador HDD de terceros
9. Utilice una consola PS2 diferente

## los Juegos no Funcionan
Es posible que algunos juegos no se inicien o presenten problemas de compatibilidad. Primero, asegúrate de que la imagen de tu juego sea un buen volcado verificado. Verifique la suma de verificación MD5 o SHA-1 de su archivo `ISO` o `BIN` y confirme que coincida con la entrada correspondiente en [redump.org](http://redump.org).

Si seleccionaste [OPL](#open-ps2-loader-opl) como iniciador del juego, intenta desactivar los trucos:
1. Inicie [OPL](#open-ps2-loader-opl), resalte el juego con el que tiene problemas en la lista de juegos y presione △
2. Selecciona "Configuración de trucos" y desactiva "PS2RD Cheat Engine"
3. Guarda los cambios e inicia el juego.

Si aún tienes problemas con juegos específicos de PS2, si seleccionaste [OPL](#open-ps2-loader-opl) como iniciador de juegos, puedes verificar si hay problemas existentes o informar uno nuevo [aquí](https://github.com/ps2homebrew/Open-PS2-Loader/issues). Si seleccionó [NHDDL](#nhddl), puede hacerlo [aquí](https://github.com/rickgaiser/neutrino/issues).

Si todos los juegos de PS1 o PS2 no se inician, sigue los pasos a continuación:

Si los juegos no se inician desde la [Colección de juegos](#colección-de-juegos) o el [Navegador](#hosdmenu), intenta lo siguiente:
1. Si tienes un [chip mod](#problemas-conocidos), desactívalo
2. Si tienes problemas para iniciar juegos de PS1, asegúrate de haber instalado correctamente los **controladores ATA BDM Assault** en una tarjeta de memoria de PS2 y de que la tarjeta esté insertada en tu consola. Las instrucciones de instalación se pueden encontrar [aquí](#instalaãão-dos-drivers-ata-bdm-assault)
3. Si tienes problemas para iniciar juegos de PS2, retira todas las tarjetas de memoria de PS2 de tu consola e inténtalo de nuevo. Si esto resuelve el problema, elimine los archivos guardados de `Su configuración del sistema` de las tarjetas de memoria, ya que los datos de configuración dañados pueden impedir que los juegos se inicien
4. Compruebe que los conectores de la consola y el adaptador de red o HDD estén limpios y libres de polvo o residuos.
5. Asegúrese de que la red o el adaptador HDD y la unidad estén bien conectados a la consola
6. Si usa un mod SATA, asegúrese de que se haya instalado correctamente

Si los juegos aún no se inician, intente cargar juegos de PS2 usando [OPL](#open-ps2-loader-opl) o [NHDDL](#nhddl) y juegos de PS1 usando [POPSLoader](#cargador-de-cop).

Si OPL se congela al inicio, elimine cualquier archivo de configuración de OPL existente de sus tarjetas de memoria PS2 o dispositivos USB conectados. También puede mantener presionado `START` mientras se inicia OPL para evitar la lectura del archivo de configuración.

Para mostrar la lista de juegos en OPL, ajuste las siguientes configuraciones:
1. Configuración > Modo de inicio HDD (APA): Desactivado
2. Configuración > Modo de inicio BDM: Automático
3. Configuración > Dispositivos BDM > HDD (GPT/MBR): Activado
4. Configuración > Guardar cambios

Si los juegos de PS2 no aparecen en la lista de juegos en [NHDDL](#nhddl) o [OPL](#open-ps2-loader-opl) (después de modificar la configuración de OPL como se describe arriba), o los juegos de PS1 no aparecen en [POPSLoader](#cargador-de-cop), intente lo siguiente:
1. Conecte la unidad PS2 directamente a su PC usando una conexión SATA interna o un adaptador SATA a USB diferente, luego reinstale [PSBBN](#instale-psbbn-y-hosdmenu) o [HOSDMenu](#instalar-hosdmenu-únicamente)
2. Utilice una unidad diferente y reinstale [PSBBN](#instale-psbbn-y-hosdmenu) o [HOSDMenu](#instalar-hosdmenu-únicamente)
3. Si su consola tiene un convertidor IDE o un mod SATA instalado, intente usar un convertidor o mod diferente
4. Utilice un adaptador de red oficial de Sony diferente o un adaptador HDD de terceros
5. Utilice una consola PS2 diferente

## Informar Problemas
Si ha probado los pasos relevantes anteriores y el problema persiste, verifique si existe un problema o abra uno nuevo [aquí](https://github.com/CosmicScale/PSBBN-Definitive-Project/issues).
Incluya todos los archivos de registro relevantes:
- `setup.log`
- `PSBBN-installer.log`
- `HOSDMenu.log`
- `game-installer.log`
- `extras.log`
- `media.log`

Los usuarios de **Linux** pueden encontrar estos registros en `PSBBN-Definitive-Project/logs`. Los usuarios de **Windows** pueden encontrar estos registros en la carpeta donde se almacenan sus juegos y archivos multimedia.

# Problemas Conocidos
- PSBBN se congelará en el logotipo de "PlayStation 2" al iniciar, si se utiliza un adaptador HDD no oficial de terceros. **Se requiere un adaptador de red oficial de Sony**.
- PSBBN se congelará al iniciar juegos o aplicaciones si un chip mod está activo. Para usar PSBBN, los chips mod deben estar desactivados.
- Casos en feega donde algún texto japonés no se pudo traducir debido a que estaba codificado en un archivo cifrado. El software Atok no ha sido traducido.
- La compatibilidad con MiniDisc no funciona a partir de la versión del parche 2.10 y superiores. Espero solucionar este problema en una actualización futura
- El teclado en pantalla predeterminado de PSBBN está configurado en japonés. Sin embargo, se agregó un teclado en pantalla en inglés de EE. UU., aunque deberá presionar el botón `SELECT` varias veces para cambiar a él. Hay un error por el cual la barra espaciadora no funciona en el teclado en pantalla en inglés de EE. UU., pero puedes ingresar un espacio presionando el botón **△** en el controlador.
- En PSBBN, el intercambio de botones × y ○ solo se admite en controladores DualShock 2
- En PSBBN, los botones multimedia en el control remoto de DVD de PS2 solo se admiten en consolas SCPH-5000x con un receptor de infrarrojos incorporado. El control remoto puede comportarse de manera errática si no hay ningún controlador conectado al puerto 1 del controlador.
- La música instalada con Music Installer solo se puede reproducir si se escribe en los primeros 3 GB de la partición de música. La música extraída de CD de audio en el [Canal de música](#canal-de-música) no se ve afectada y puede utilizar toda la capacidad de la partición.
- PSBBN solo admite fechas hasta finales de 2030. Al configurar la hora y la fecha, el año debe establecerse en 2030 o menos.
- Las instalaciones japonesas de PSBBN fallarán en unidades de menos de 128 GB.
- La partición exFAT no puede exceder los 2 TB. Cuando utilice una unidad más grande, el espacio restante más allá será inutilizable.
- **wLaunchELF** y otras aplicaciones nativas de PS2 pueden no crear particiones APA en la unidad de PS2. Para evitar daños en la unidad, las nuevas particiones APA solo deben crearse utilizando la versión de **PFS Shell** incluida con este proyecto.
- Las particiones APA no deben crearse más allá del espacio reservado para APA durante la instalación. Al hacerlo, se sobrescribirán los datos en la partición exFAT.

# Créditos
**PSBBN Definitive Project - Copyright © 2024-2026 por [CosmicScale](https://github.com/CosmicScale)**
- `PSBBN-Definitive-Patch.sh`, `Setup.sh`, `PSBBN-Installer.sh`, `HOSDMenu-Installer.sh`, `Game-Installer.sh`, `Media-Installer.sh`, `music-installer.py`, `psmbuild.py`, `Extras.sh`, `art_downloader.py`, `list-builder.py`, `list-sorter.py`, `ps2iconmaker.sh`, `AppDB.csv`, `TitlesDB_PS1.csv`, `TitlesDB_PS2.csv`, `ps1_vmc_groups.list`, `POP-game-fixes.list`, `game-selector.py` escrito por [CosmicScale](https://github.com/CosmicScale)
- `game-selector.py` basado en un guión escrito por [Luiz Antonio Lazoti](https://github.com/luizoti)
- `PSBBN-Launcher-For-Windows.ps1` escrito por Yornn
- PSBBN Icono 3D diseñado por Yornn
- Utiliza el código APA-Jail del [PS2 HDD Decryption Helper](https://www.psx-place.com/resources/ps2-hdd-decryption-helper.1507/) de [Berion](https://www.psx-place.com/members/berion.1431/)
- Contiene código de [`list_builder.py`](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin/blob/main/List%20Builder/list_builder.py) de [XEB+ neutrino Launcher Plugin](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin) de [sync-on-luma](https://github.com/sync-on-luma)
- Contiene código de [`ps2iconmaker.sh`](https://github.com/CosmicScale/HDD-OSD-Icon-Database/issues/1#issuecomment-2852499188) de [Sakitoshi](https://github.com/Sakitoshi)
- Contiene datos de [`TitlesDB_PS1_English.txt`](https://github.com/GDX-X/PFS-BatchKit-Manager/blob/main/PFS-BatchKit-Manager/BAT/TitlesDB/TitlesDB_PS1_English.txt) y [`TitlesDB_PS2_English.txt`](https://github.com/GDX-X/PFS-BatchKit-Manager/blob/main/PFS-BatchKit-Manager/BAT/TitlesDB/TitlesDB_PS2_English.txt) del [PFS-BatchKit-Manager](https://github.com/GDX-X/PFS-BatchKit-Manager) de [GDX-X](https://github.com/GDX-X)
- Contiene datos de [`vmc_groups.list`](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin/blob/main/List%20Builder/vmc_groups.list) de [XEB+ neutrino Launcher Plugin](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin) de [sync-on-luma](https://github.com/sync-on-luma)
- PSBBN Equipo de localización
  - Inglés — [Escala Cósmica](https://github.com/CosmicScale)
  - Alemán — [Argo707](https://github.com/Argo707)
  - Italiano — [plamadika](https://github.com/plamadika) & [lcipria](https://github.com/lcipria)
  - Portugués brasileño — [Emerson Teles (Emertels)](https://github.com/Emertels)
  - Español — [Ignacio Trillo (Nacheras)](https://github.com/Nacheras) & [ViZoRRetrogames](https://github.com/ViZoRRetrogames)
  - Francés — [Bistroww](https://github.com/Bistroww) y [iSlickick](https://github.com/iSlickick)
  - Húngaro — [BeLANzO666](https://github.com/BeLANzO666)

**PSBBN Definitive Project Utiliza las Siguientes Herramientas y Aplicaciones Caseras de PS2:**
- [Base de datos de arte PSBBN](https://github.com/CosmicScale/psbbn-art-database) creada y mantenida por [CosmicScale](https://github.com/CosmicScale)
- [HDD-OSD Icon Database](https://github.com/CosmicScale/HDD-OSD-Icon-Database) creado y mantenido por [CosmicScale](https://github.com/CosmicScale)
- [Menú OSDM](https://github.com/pcm720/OSDMenu) por [pcm720](https://github.com/pcm720)
- [Comprobador de encabezado de partición APA](https://github.com/pink1stools/APA-Partition-Header-Checksumer/) por [Pink1](https://github.com/pink1stools) y [Berion](https://www.psx-place.com/members/berion.1431/). [Puerto Linux](https://github.com/bucanero/save-decrypters/tree/master/ps2-apa-header-checksum) por [Bucanero](https://github.com/Bucanero)
- [PFS Shell](https://github.com/AKuHAK/pfsshell/tree/ext2) y [HDL Dump](https://github.com/AKuHAK/hdl-dump/tree/8M) con partición APA de 8 MB y modificaciones EXT2 mediante [AKuHAK](https://github.com/AKuHAK)
- PFS Fuse de [PFS Shell](https://github.com/ps2homebrew/pfsshell) por [PS2 Homebrew Projects](https://github.com/ps2homebrew)
- Extractor de PSU de [PSV Save Converter](https://github.com/bucanero/psv-save-converter) de [Bucanero](https://github.com/Bucanero)
- [`ziso.py`](https://github.com/ps2homebrew/Open-PS2-Loader/blob/master/pc/ziso.py) por Virtuous Flame
- cue2pops de [pops2cue](https://github.com/bucanero/pops2cue) por [Bucanero](https://github.com/Bucanero)
- [Open PS2 Loader](https://github.com/ps2homebrew/Open-PS2-Loader) de [PS2 Homebrew Projects](https://github.com/ps2homebrew) con contribuciones BDM de [KrahJohlito](https://github.com/KrahJohlito) y modificaciones de inicio automático de [CosmicScale](https://github.com/CosmicScale)
- [Open PS2 Loader Widescreen Hacks](https://github.com/PS2-Widescreen/OPL-Widescreen-Cheats) por [PS2-Widescreen](https://github.com/PS2-Widescreen)
- [Neutrino](https://github.com/rickgaiser/neutrino) por [Rick Gaiser](https://github.com/rickgaiser)
- [NHDDL](https://github.com/pcm720/nhddl) por [pcm720](https://github.com/pcm720)
- [POPStarter](https://www.psx-place.com/resources/popstarter.683/) por [KrHACKen](https://www.psx-place.com/members/krhacken.98/)
- [POPSLoader](https://github.com/NathanNeurotic/POPSLoader) por [NathanNeurotic (Ripto)](https://github.com/NathanNeurotic)
- [Correcciones de HugoPocked POPSarter](https://www.psx-place.com/threads/hugopocked-fixes-for-popstarter.39750/) por [HugoPocked](https://ko-fi.com/hugopocked)
- [ATA BDM Assault](https://github.com/saildot4k/ATA-Assault) por [R3Z3N](https://github.com/saildot4k)
- [wLaunchELF_R3Z](https://github.com/saildot4k/wLaunchELF_R3Z) por [R3Z3N](https://github.com/saildot4k)
- [R3CONFIGURADOR](https://github.com/saildot4k/R3CONFIGURATOR) por [R3Z3N](https://github.com/saildot4k)
- Portada de PS2 de [copias de seguridad de OPL Manager Art DB](https://oplmanager.com/site/index.php?backups)
- Diseño de la aplicación de [OPL B-APPS Cover Pack](https://www.psx-place.com/resources/opl-b-apps-cover-pack.1440/) y [OPL Discs & Boxes Pack](https://www.psx-place.com/resources/opl-discs-boxes-pack.1439/) cortesía de [Berion](https://www.psx-place.com/resources/authors/berion.1431/)
- Canales en línea alojados y traducidos al inglés por vitas155 en [PSBBN.ru](https://psbbn.ru/), con la excepción de PlayStation Now! y Konami Channel, traducido al inglés por [CosmicScale](https://github.com/CosmicScale)

**Bibliotecas y Binarios de Terceros:**  
- `vmlinux` **BB Navigator kernel (Linux 2.4.17)** – Código fuente disponible [aquí](https://github.com/CosmicScale/PSBBN-Definitive-Patch-Kernel)
- **SQLite v2.8.17** de [sqlite.org](https://www.sqlite.org)
- **mkfs.exfat (exfatprogs 1.2.2)** de [exfatprogs](https://github.com/exfatprogs/exfatprogs)
- `binmerge.py` de [binmerge](https://github.com/putnam/binmerge)

**Todas las Bibliotecas y Utilidades Son de Código Abierto y Se Utilizan de Acuerdo Con Sus Respectivas Licencias.**

**Gracias:**
- [Bucanero](https://github.com/Bucanero) por compilar los binarios de ARM64
- A todos los miembros del [equipo SAS/UMCS](https://ps2homebrewstore.com/thanks/) por su trabajo continuo en la [PS2 Homebrew Store](https://ps2homebrewstore.com/)
- Un agradecimiento especial a [pcm720](https://github.com/pcm720) por parchear `osdboot.elf` para evitar la verificación de seguridad CRC.
