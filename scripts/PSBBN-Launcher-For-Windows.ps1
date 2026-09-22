#Requires -Version 5.1

# User must open its execution policy by running
# `Set-ExecutionPolicy -ExecutionPolicy Unrestricted`
# and choose "Yes to All"

param(
  [Alias("logs", "log")]
  [switch]$LogsEnabled = $false
)

# the version of this script itself, useful to know if a user is running the latest version
$version = "1.3.0"

# the label of the WSL machine. Still based on Debian, but this label makes sure we get the
# machine created by this script and not some pre-existing Debian the user had.
$wslLabel = "PSBBN"

# the name of the exfat volume created by the psbbn installer with apajail
# this is used to attempt to detect which disks have an install of PSBBN
$oplVolumeName = "OPL"

# a list of subfolders to be created in the main folder if missing
$defaultFolders = @('DVD', 'CD', 'POPS', 'APPS', 'music', 'movie', 'photo')

# the git repository and branch the toolkit is cloned from. The PlayOnline
# build lives on a fork; upstream's main has no option 7.
$gitRepo = "https://github.com/PSChuze/PSBBN-Definitive-Project.git"
$gitBranch = "playonline"

# the console size that is set at the start of the script
$consoleWidth = 110
$consoleHeight = 45

# the filename of the file holding the last path used
$pathFilename = "path.cfg"

# the minimum disk size allowed to be picked, in gigabytes
$minimumDiskSize = 31

# where the network drive chosen by the user will be mounted in wsl
$networkDriveMountpoint = "/mnt/PSBBN-network-drive"

# --- DO NOT MODIFY THE VARIABLES BELOW ---

# the escape character used to color text
$e = [char] 27

# this make wsl commands output utf8 instead of utf16_LE
$env:WSL_UTF8 = 1

# flag potentially raised when enabling features, signaling a reboot is necessary to finish the install
$global:isRestartRequired = $false

# stores Get-Disk's result to avoid multiple calls
$global:diskList = $null

# stores the disk number (obtained with Get-Disk) that was selected via diskPicker
$global:selectedDisk = -1

# keeps track of if a drive was manually mounted (for example a network drive)
$global:isDriveMounted = $false

# --- Detect Windows language ---
$winLang = (Get-ItemProperty 'HKCU:\Control Panel\International\User Profile').Languages[0]

# --- Map to internal language key ---
switch -wildcard ($winLang) {
    "ja*" { $winLang = "jpn" }
    "fr*" { $winLang = "fre" }
    "es*" { $winLang = "spa" }
    "de*" { $winLang = "ger" }
    "it*" { $winLang = "ita" }
    "pt*" { $winLang = "por" }
    "hu*" { $winLang = "hun" }
    default { $winLang = "eng" }
}

# --- Embedded translations ---
$TEXT = @{
    eng = @{
        prompt_01 = "You need to restart your computer to apply newly installed features."
        prompt_02 = "Once you have restarted, simply run this script again."
        prompt_03 = "You are about to restart your PC. Save your work, type 'restart', and press ENTER."
        prompt_04 = "The WSL distribution will prompt you to set a username and a password."
        prompt_05 = "The username must start with a lowercase letter and contain only letters and numbers."
        prompt_06 = "You must set a password."
        prompt_07 = "Once this is complete, type 'exit' and press ENTER to continue."
        prompt_08 = "List of available disks:"
        prompt_09 = "Select a disk for PSBBN by entering a number, or press 'r' to refresh the list."
        prompt_10 = "Invalid input. Please try again."
        prompt_11 = "Selected disk number:"
        prompt_12 = "The following path was used previously:"
        prompt_13 = "Do you want to continue using it?"
        prompt_14 = "Next, you will be prompted to select or create a folder on your PC (for example, C:\PSBBN)."
        prompt_15 = "This folder is for all the games, music, videos, and image files you plan to install."
        prompt_16 = "The following path has been chosen:"
        prompt_17 = "Before you continue, you can add your games and other media to this folder:"
        prompt_18 = "See the PSBBN Definitive Project Readme for more information."
        prompt_19 = "A network drive has been selected, so it needs to be mounted. You will be asked for your Linux password."
        prompt_20 = "The network drive needs to be unmounted. You will be asked for your Linux password."
        prompt_21 = "Have fun exploring PSBBN!"

        warn_01 = "PSBBN requires a disk with a minimum capacity of 32 GB."
        warn_02 = "Virtualization is not enabled. It is required to run PSBBN scripts."
        warn_03 = "If you have an AMD CPU, enable SVM in your BIOS."
        warn_04 = "If you have an Intel CPU, enable VT-x in your BIOS."
        warn_05 = "Consult your motherboard manual if you are having trouble finding this setting."
        warn_06 = "You should not store your files on the linux filesystem."
        warn_07 = "Create a folder on your Windows disk and put your ISOs and others files there."
        warn_08 = "Once this is done, you can run this script again and select the new folder."
        warn_09 = "No folder was selected, re-run this script and choose a folder."

        error_01 = "Your Windows version is not up-to-date."
        error_02 = "A build above 19041 is required."
        error_03 = "The script could not install Git and therefore cannot continue."
        error_04 = "Check your internet connection and try running the script again."
        error_05 = "If the problem persists, try setting the WSL network mode to 'mirrored' and then try again."
        error_06 = "To do this, open the 'WSL Settings' application, then 'Networking' tab."
        error_07 = "You should see the 'Networking Mode' option there. Select 'Mirrored'."
        error_08 = "The script failed to list the disks."
        error_09 = "This is often due to a corrupted WMI repository."
        error_10 = "Perform a web search for '0x80041031,Get-Disk' to find solutions."
        error_11 = "WSL is not available on this computer."
        error_12 = "USB thumbdrives and SD card readers are not supported by the PSBBN Launcher for Windows"
    }

    jpn = @{
        prompt_01 = "新しくインストールされた機能を適用するには、コンピューターを再起動する必要があります。"
        prompt_02 = "再起動後、このスクリプトをもう一度実行してください。"
        prompt_03 = "PCを再起動しようとしています。作業内容を保存し、「restart」と入力して ENTER キーを押してください。"
        prompt_04 = "WSL ディストリビューションでユーザー名とパスワードの設定を求められます。"
        prompt_05 = "ユーザー名は小文字の英字で始まり、英数字のみを含める必要があります。"
        prompt_06 = "パスワードを設定する必要があります。"
        prompt_07 = "これが完了したら、'exit'と入力してENTERを押すと続行できます。"
        prompt_08 = "利用可能なディスク一覧:"
        prompt_09 = "番号を入力して PSBBN 用のディスクを選択するか、「r」を押して一覧を更新してください。"
        prompt_10 = "無効な入力です。もう一度お試しください。"
        prompt_11 = "選択されたディスク番号:"
        prompt_12 = "以前使用されたパス:"
        prompt_13 = "引き続きこれを使用しますか？"
        prompt_14 = "次に、PC 上のフォルダーを選択または作成するよう求められます（例: C:\\PSBBN）。"
        prompt_15 = "このフォルダーには、インストール予定のゲーム、音楽、動画、イメージファイルを保存します。"
        prompt_16 = "次のパスが選択されました:"
        prompt_17 = "続行する前に、このフォルダーへゲームやその他のメディアを追加できます:"
        prompt_18 = "詳細については、PSBBN Definitive Project の Readme を参照してください。"
        prompt_19 = "ネットワークドライブが選択されたため、マウントする必要があります。Linux のパスワードの入力を求められます。"
        prompt_20 = "ネットワークドライブをアンマウントする必要があります。Linux のパスワードの入力を求められます。"
        prompt_21 = "PSBBN の探索をお楽しみください！"

        warn_01 = "PSBBN には最低 32 GB の容量を持つディスクが必要です。"
        warn_02 = "仮想化が有効になっていません。PSBBN スクリプトの実行には必要です。"
        warn_03 = "AMD CPU を使用している場合は、BIOS で SVM を有効にしてください。"
        warn_04 = "Intel CPU を使用している場合は、BIOS で VT-x を有効にしてください。"
        warn_05 = "この設定が見つからない場合は、マザーボードのマニュアルを参照してください。"
        warn_06 = "ファイルを Linux ファイルシステム上に保存しないでください。"
        warn_07 = "Windows ドライブ上にフォルダーを作成し、ISO やその他のファイルをそこに保存してください。"
        warn_08 = "これが完了したら、このスクリプトを再実行して新しいフォルダーを選択できます。"
        warn_09 = "フォルダーが選択されませんでした。このスクリプトを再実行してフォルダーを選択してください。"

        error_01 = "お使いの Windows のバージョンは最新ではありません。"
        error_02 = "ビルド 19041 より新しいバージョンが必要です。"
        error_03 = "スクリプトは Git をインストールできなかったため、続行できません。"
        error_04 = "インターネット接続を確認し、もう一度スクリプトを実行してください。"
        error_05 = "問題が解決しない場合は、WSL のネットワークモードを「mirrored」に設定してから再試行してください。"
        error_06 = "これを行うには、「WSL Settings」アプリケーションを開き、「Networking」タブを開いてください。"
        error_07 = "そこに「Networking Mode」オプションが表示されるはずです。「Mirrored」を選択してください。"
        error_08 = "スクリプトはディスク一覧の取得に失敗しました。"
        error_09 = "これは WMI リポジトリの破損が原因であることがよくあります。"
        error_10 = "「0x80041031,Get-Disk」をウェブ検索して解決策を探してください。"
        error_11 = "このコンピューターではWSLは利用できません。"
        error_12 = "USBメモリおよびSDカードリーダーはWindows版PSBBNランチャーではサポートされていません。"
    }

    fre = @{
        prompt_01 = "Vous devez redémarrer votre ordinateur pour appliquer les fonctionnalités nouvellement installées."
        prompt_02 = "Une fois que vous avez redémarré, relancez simplement ce script."
        prompt_03 = "Redémarrage imminent du PC. Enregistrez votre travail, tapez 'restart' et appuyez sur ENTRÉE."
        prompt_04 = "La distribution WSL vous demandera de définir un nom d'utilisateur et un mot de passe."
        prompt_05 = "Le nom d'utilisateur doit commencer par une lettre minuscule et ne contenir que lettres et chiffres."
        prompt_06 = "Vous devez définir un mot de passe."
        prompt_07 = "Une fois cela terminé, vous pouvez taper 'exit' et appuyer sur ENTER pour continuer."
        prompt_08 = "Liste des disques disponibles :"
        prompt_09 = "Sélectionnez un disque pour PSBBN en entrant un numéro, ou appuyez sur 'r' pour actualiser la liste."
        prompt_10 = "Entrée invalide. Veuillez réessayer."
        prompt_11 = "Numéro de disque sélectionné :"
        prompt_12 = "Le chemin suivant a été utilisé précédemment :"
        prompt_13 = "Souhaitez-vous continuer à l'utiliser ?"
        prompt_14 = "Ensuite, il vous sera demandé de sélectionner ou de créer un dossier sur votre PC (par exemple, C:\PSBBN)."
        prompt_15 = "Ce dossier est destiné à tous les jeux, musiques, vidéos et fichiers image que vous prévoyez d'installer."
        prompt_16 = "Le chemin suivant a été choisi :"
        prompt_17 = "Avant de continuer, vous pouvez ajouter vos jeux et autres médias à ce dossier :"
        prompt_18 = "Consultez le fichier Readme du projet PSBBN Definitive pour plus d'informations."
        prompt_19 = "Un lecteur réseau a été sélectionné, il doit donc être monté. Votre mot de passe Linux vous sera demandé."
        prompt_20 = "Le lecteur réseau doit être démonté. Votre mot de passe Linux vous sera demandé."
        prompt_21 = "Amusez-vous bien à explorer PSBBN !"

        warn_01 = "PSBBN nécessite un disque d'une capacité minimale de 32 Go."
        warn_02 = "La virtualisation n'est pas activée. Elle est nécessaire pour exécuter les scripts PSBBN."
        warn_03 = "Si vous avez un processeur AMD, activez SVM dans votre BIOS."
        warn_04 = "Si vous avez un processeur Intel, activez VT-x dans votre BIOS."
        warn_05 = "Consultez le manuel de votre carte mère si vous avez du mal à trouver ce paramètre."
        warn_06 = "Vous ne devez pas stocker vos fichiers sur le système de fichiers Linux."
        warn_07 = "Créez un dossier sur votre disque Windows et placez-y vos ISO ainsi que vos autres fichiers."
        warn_08 = "Une fois cela fait, vous pouvez relancer ce script et sélectionner le nouveau dossier."
        warn_09 = "Aucun dossier n'a été sélectionné. Relancez ce script et choisissez un dossier."

        error_01 = "Votre version de Windows n'est pas à jour."
        error_02 = "Une version supérieure à 19041 est requise."
        error_03 = "Le script n'a pas pu installer Git et ne peut donc pas continuer."
        error_04 = "Vérifiez votre connexion Internet et essayez de relancer le script."
        error_05 = "Si le problème persiste, essayez de définir le mode réseau de WSL sur « mirrored » puis réessayez."
        error_06 = "Pour ce faire, ouvrez l'application « Paramètres WSL », puis l'onglet « Réseau »."
        error_07 = "Vous devriez y voir l'option « Mode réseau ». Sélectionnez « Mirrored »."
        error_08 = "Le script n'a pas réussi à lister les disques."
        error_09 = "Cela est souvent dû à une corruption du dépôt WMI."
        error_10 = "Effectuez une recherche Web sur « 0x80041031,Get-Disk » pour trouver des solutions."
        error_11 = "WSL n'est pas disponible sur cet ordinateur."
        error_12 = "Les clés USB et lecteurs de cartes SD ne sont pas pris en charge par le lanceur PSBBN pour Windows."
    }

    ger = @{
        prompt_01 = "Sie müssen Ihren Computer neu starten, um die neu installierten Funktionen anzuwenden."
        prompt_02 = "Sobald Sie neu gestartet haben, führen Sie dieses Skript einfach erneut aus."
        prompt_03 = "Ihr PC wird jetzt neu gestartet. Speichern Sie Ihre Arbeit, geben Sie 'restart' ein und drücken Sie ENTER."
        prompt_04 = "Die WSL-Distribution wird Sie auffordern, einen Benutzernamen und ein Passwort festzulegen."
        prompt_05 = "Der Benutzername muss mit einem Kleinbuchstaben beginnen und darf nur Buchstaben und Zahlen enthalten."
        prompt_06 = "Sie müssen ein Passwort festlegen."
        prompt_07 = "Sobald dies abgeschlossen ist, können Sie 'exit' eingeben und ENTER drücken, um fortzufahren."
        prompt_08 = "Liste der verfügbaren Laufwerke:"
        prompt_09 = "Wählen Sie ein PSBBN-Laufwerk durch Eingabe einer Zahl oder drücken Sie 'r' zum Aktualisieren der Liste."
        prompt_10 = "Ungültige Eingabe. Bitte versuchen Sie es erneut."
        prompt_11 = "Ausgewählte Laufwerksnummer:"
        prompt_12 = "Der folgende Pfad wurde zuvor verwendet:"
        prompt_13 = "Möchten Sie ihn weiterhin verwenden?"
        prompt_14 = "Als Nächstes wählen oder erstellen Sie einen Ordner auf Ihrem PC (z. B. C:\\PSBBN)."
        prompt_15 = "Dieser Ordner ist für alle Spiele, Musik-, Video- und Image-Dateien vorgesehen, die Sie installieren möchten."
        prompt_16 = "Der folgende Pfad wurde ausgewählt:"
        prompt_17 = "Bevor Sie fortfahren, können Sie Ihre Spiele und andere Medien zu diesem Ordner hinzufügen:"
        prompt_18 = "Weitere Informationen finden Sie in der Readme des PSBBN Definitive Project."
        prompt_19 = "Ein Netzlaufwerk wurde ausgewählt und muss eingebunden werden. Ihr Linux-Passwort wird abgefragt."
        prompt_20 = "Das Netzlaufwerk muss ausgehängt werden. Sie werden nach Ihrem Linux-Passwort gefragt."
        prompt_21 = "Viel Spaß beim Erkunden von PSBBN!"

        warn_01 = "PSBBN benötigt ein Laufwerk mit einer Mindestkapazität von 32 GB."
        warn_02 = "Die Virtualisierung ist nicht aktiviert. Sie wird benötigt, um die PSBBN-Skripte auszuführen."
        warn_03 = "Wenn Sie eine AMD-CPU haben, aktivieren Sie SVM in Ihrem BIOS."
        warn_04 = "Wenn Sie eine Intel-CPU haben, aktivieren Sie VT-x in Ihrem BIOS."
        warn_05 = "Lesen Sie im Handbuch Ihres Mainboards nach, wenn Sie diese Einstellung nicht finden."
        warn_06 = "Sie sollten Ihre Dateien nicht im Linux-Dateisystem speichern."
        warn_07 = "Erstellen Sie einen Ordner auf Ihrem Windows-Laufwerk und speichern Sie dort Ihre ISOs und andere Dateien."
        warn_08 = "Sobald dies erledigt ist, können Sie dieses Skript erneut ausführen und den neuen Ordner auswählen."
        warn_09 = "Es wurde kein Ordner ausgewählt. Führen Sie dieses Skript erneut aus und wählen Sie einen Ordner aus."

        error_01 = "Ihre Windows-Version ist nicht auf dem neuesten Stand."
        error_02 = "Eine Build-Version über 19041 ist erforderlich."
        error_03 = "Das Skript konnte Git nicht installieren und kann daher nicht fortfahren."
        error_04 = "Überprüfen Sie Ihre Internetverbindung und versuchen Sie, das Skript erneut auszuführen."
        error_05 = "Falls das Problem weiterhin besteht stellen Sie WSL-Netzwerkmodus auf 'mirrored' und versuchen Sie erneut."
        error_06 = "Öffnen Sie dazu die Anwendung 'WSL Settings' und anschließend die Registerkarte 'Networking'."
        error_07 = "Dort sollten Sie die Option 'Networking Mode' sehen. Wählen Sie 'Mirrored' aus."
        error_08 = "Das Skript konnte die Laufwerke nicht auflisten."
        error_09 = "Dies wird häufig durch ein beschädigtes WMI-Repository verursacht."
        error_10 = "Führen Sie eine Websuche nach '0x80041031,Get-Disk' durch, um Lösungen zu finden."
        error_11 = "WSL ist auf diesem Computer nicht verfügbar."
        error_12 = "USB-Sticks und SD-Kartenleser werden vom PSBBN-Launcher für Windows nicht unterstützt."
    }

    hun = @{
        prompt_01 = "A frissen telepített funkciók alkalmazásához újra kell indítania a számítógépet."
        prompt_02 = "Az újraindítás után egyszerűen futtassa újra ezt a szkriptet."
        prompt_03 = "A számítógép újraindul. Mentse a munkáját, írja be: 'restart', majd nyomja meg az ENTER-t"
        prompt_04 = "A WSL disztribúció felhasználónevet és jelszót fog kérni Öntől."
        prompt_05 = "A felhasználónévnek kisbetűvel kell kezdődnie, és csak betűket és számokat tartalmazhat."
        prompt_06 = "Meg kell adnia egy jelszót."
        prompt_07 = "Miután ez befejeződött, beírhatja, hogy 'exit', és nyomja meg az ENTER-t a folytatáshoz."
        prompt_08 = "Elérhető lemezek listája:"
        prompt_09 = "Válasszon lemezt a PSBBN számára egy szám megadásával, vagy nyomja meg az 'r' gombot a frissítéshez."
        prompt_10 = "Érvénytelen bevitel. Kérjük, próbálja újra."
        prompt_11 = "Kiválasztott lemez száma:"
        prompt_12 = "A következő elérési út lett korábban használva:"
        prompt_13 = "Szeretné továbbra is ezt használni?"
        prompt_14 = "Ezután ki kell választania vagy létre kell hoznia egy mappát a számítógépén (például: C:\\PSBBN)."
        prompt_15 = "Ez a mappa szolgál az összes telepíteni kívánt játék, zene, videó és képfájl tárolására."
        prompt_16 = "A következő elérési út lett kiválasztva:"
        prompt_17 = "Mielőtt folytatná, hozzáadhatja játékait és egyéb médiatartalmait ehhez a mappához:"
        prompt_18 = "További információkért tekintse meg a PSBBN Definitive Project Readme fájlját."
        prompt_19 = "Hálózati meghajtó lett kiválasztva, ezért azt csatlakoztatni kell. A rendszer kérni fogja a Linux-jelszavát."
        prompt_20 = "A hálózati meghajtót le kell választani. A rendszer kérni fogja a Linux-jelszavát."
        prompt_21 = "Jó szórakozást a PSBBN felfedezéséhez!"

        warn_01 = "A PSBBN használatához legalább 32 GB kapacitású lemez szükséges."
        warn_02 = "A virtualizáció nincs engedélyezve. A PSBBN szkriptek futtatásához szükséges."
        warn_03 = "Ha AMD processzora van, engedélyezze az SVM-et a BIOS-ban."
        warn_04 = "Ha Intel processzora van, engedélyezze a VT-x funkciót a BIOS-ban."
        warn_05 = "Ha nem találja ezt a beállítást, tekintse meg az alaplap kézikönyvét."
        warn_06 = "Ne tárolja fájljait a Linux fájlrendszerén."
        warn_07 = "Hozzon létre egy mappát a Windows-meghajtóján, és helyezze oda az ISO-fájlokat és egyéb fájlokat."
        warn_08 = "Ha ezzel végzett, újra futtathatja ezt a szkriptet, és kiválaszthatja az új mappát."
        warn_09 = "Nem lett kiválasztva mappa. Futtassa újra ezt a szkriptet, és válasszon egy mappát."

        error_01 = "A Windows-verziója nincs naprakész állapotban."
        error_02 = "19041-nél újabb build szükséges."
        error_03 = "A szkript nem tudta telepíteni a Gitet, ezért nem tud tovább futni."
        error_04 = "Ellenőrizze az internetkapcsolatát, majd próbálja meg újra futtatni a szkriptet."
        error_05 = "Ha a probléma továbbra is fennáll, állítsa a WSL hálózati módját 'mirrored' értékre, majd próbálja újra."
        error_06 = "Ehhez nyissa meg a 'WSL Settings' alkalmazást, majd a 'Networking' lapot."
        error_07 = "Ott látnia kell a 'Networking Mode' beállítást. Válassza a 'Mirrored' lehetőséget."
        error_08 = "A szkript nem tudta lekérni a lemezek listáját."
        error_09 = "Ezt gyakran egy sérült WMI-tár okozza."
        error_10 = "Keressen rá a weben a '0x80041031,Get-Disk' kifejezésre a megoldások megtalálásához."
        error_11 = "A WSL nem érhető el ezen a számítógépen."
        error_12 = "Az USB-meghajtók és SD-kártyaolvasók nem támogatottak a Windows-hoz készült PSBBN Launcherben."
    }

    ita = @{
        prompt_01 = "È necessario riavviare il computer per applicare le funzionalità appena installate."
        prompt_02 = "Dopo il riavvio, esegui semplicemente di nuovo questo script."
        prompt_03 = "Il PC sta per essere riavviato. Salva il tuo lavoro, digita 'restart' e premi INVIO."
        prompt_04 = "La distribuzione WSL ti chiederà di impostare un nome utente e una password."
        prompt_05 = "Il nome utente deve iniziare con una lettera minuscola e contenere solo lettere e numeri."
        prompt_06 = "Devi impostare una password."
        prompt_07 = "Una volta completato, puoi digitare 'exit' e premere ENTER per continuare."
        prompt_08 = "Elenco dei dischi disponibili:"
        prompt_09 = "Seleziona un disco per PSBBN inserendo un numero oppure premi 'r' per aggiornare l'elenco."
        prompt_10 = "Input non valido. Riprova."
        prompt_11 = "Numero del disco selezionato:"
        prompt_12 = "Il seguente percorso è stato utilizzato in precedenza:"
        prompt_13 = "Vuoi continuare a usarlo?"
        prompt_14 = "Successivamente, ti verrà chiesto di selezionare o creare una cartella sul tuo PC (ad esempio C:\\PSBBN)."
        prompt_15 = "Questa cartella è destinata a tutti i giochi, la musica, i video e i file immagine che intendi installare."
        prompt_16 = "È stato scelto il seguente percorso:"
        prompt_17 = "Prima di continuare, puoi aggiungere i tuoi giochi e altri contenuti multimediali a questa cartella:"
        prompt_18 = "Consulta il Readme del PSBBN Definitive Project per ulteriori informazioni."
        prompt_19 = "È stata selezionata un'unità di rete, quindi deve essere montata. Ti verrà richiesta la password di Linux."
        prompt_20 = "L'unità di rete deve essere smontata. Ti verrà richiesta la password di Linux."
        prompt_21 = "Buon divertimento nell'esplorare PSBBN!"

        warn_01 = "PSBBN richiede un disco con una capacità minima di 32 GB."
        warn_02 = "La virtualizzazione non è abilitata. È necessaria per eseguire gli script di PSBBN."
        warn_03 = "Se hai una CPU AMD, abilita SVM nel BIOS."
        warn_04 = "Se hai una CPU Intel, abilita VT-x nel BIOS."
        warn_05 = "Consulta il manuale della scheda madre se hai difficoltà a trovare questa impostazione."
        warn_06 = "Non dovresti archiviare i tuoi file nel filesystem Linux."
        warn_07 = "Crea una cartella sul disco Windows e inserisci lì i tuoi file ISO e gli altri file."
        warn_08 = "Una volta completato, puoi rieseguire questo script e selezionare la nuova cartella."
        warn_09 = "Nessuna cartella è stata selezionata. Esegui nuovamente questo script e scegli una cartella."

        error_01 = "La tua versione di Windows non è aggiornata."
        error_02 = "È richiesta una build superiore alla 19041."
        error_03 = "Lo script non è riuscito a installare Git e pertanto non può continuare."
        error_04 = "Controlla la connessione Internet e prova a eseguire nuovamente lo script."
        error_05 = "Se il problema persiste, prova a impostare la modalità di rete di WSL su 'mirrored' e riprova."
        error_06 = "Per farlo, apri l'applicazione 'WSL Settings', quindi la scheda 'Networking'."
        error_07 = "Dovresti vedere l'opzione 'Networking Mode'. Seleziona 'Mirrored'."
        error_08 = "Lo script non è riuscito a elencare i dischi."
        error_09 = "Ciò è spesso dovuto a un repository WMI danneggiato."
        error_10 = "Esegui una ricerca sul Web per '0x80041031,Get-Disk' per trovare delle soluzioni."
        error_11 = "WSL non è disponibile su questo computer."
        error_12 = "Le chiavette USB e i lettori di schede SD non sono supportati dal launcher PSBBN per Windows."
    }

    por = @{
        prompt_01 = "É necessário reiniciar o computador para aplicaplicar os recursos recém-instalados."
        prompt_02 = "Após reiniciar, basta executar este script novamente."
        prompt_03 = "O PC está prestes a ser reiniciado. Salve o trabalho, digite 'restart' e pressione ENTER."
        prompt_04 = "A distribuição WSL solicitará um nome de usuário e uma senha."
        prompt_05 = "O nome de usuário deve começar com uma letra minúscula e conter apenas letras e números."
        prompt_06 = "É obrigatório definir uma senha."
        prompt_07 = "Após concluir, digite 'exit' e pressione ENTER para retornar."
        prompt_08 = "Lista de discos disponíveis:"
        prompt_09 = "Selecione um disco para o PSBBN digitando um número ou pressione 'r' para atualizar a lista."
        prompt_10 = "Entrada inválida. Tente novamente."
        prompt_11 = "Número do disco selecionado:"
        prompt_12 = "O seguinte caminho foi usado anteriormente:"
        prompt_13 = "Você deseja continuar usando-o?"
        prompt_14 = "Em seguida, selecione ou crie uma pasta no PC (por exemplo, C:\PSBBN)."
        prompt_15 = "Esta pasta é destinada a todos os jogos, músicas, vídeos e arquivos de imagem que serão instalados."
        prompt_16 = "O seguinte caminho foi escolhido:"
        prompt_17 = "Antes de continuar, adicione os jogos e outras mídias a esta pasta:"
        prompt_18 = "Consulte o Readme do PSBBN Definitive Project para mais informações."
        prompt_19 = "Uma unidade de rede foi selecionada e precisa ser montada. A senha do Linux será solicitada."
        prompt_20 = "A unidade de rede precisa ser desmontada. A senha do Linux será solicitada."
        prompt_21 = "Divirta-se explorando o PSBBN!"

        warn_01 = "O PSBBN requer um disco com capacidade mínima de 32 GB."
        warn_02 = "A virtualização não está ativada. Ela é necessária para executar os scripts do PSBBN."
        warn_03 = "Para CPUs AMD, ative o SVM na BIOS."
        warn_04 = "Para CPUs Intel, ative o VT-x na BIOS."
        warn_05 = "Consulte o manual da placa-mãe caso tenha dificuldade em encontrar essa configuração."
        warn_06 = "Não armazene os arquivos no sistema de arquivos Linux."
        warn_07 = "Crie uma pasta no disco do Windows e coloque nela os ISOs e outros arquivos."
        warn_08 = "Após concluir, execute este script novamente e selecione a nova pasta."
        warn_09 = "Nenhuma pasta foi selecionada. Execute este script novamente e escolha uma pasta."

        error_01 = "A versão do Windows está desatualizada."
        error_02 = "É necessária uma build superior à 19041."
        error_03 = "O script não conseguiu instalar o Git e, portanto, não pode continuar."
        error_04 = "Verifique a conexão com a internet e tente executar o script novamente."
        error_05 = "Se o problema persistir, defina o modo de rede do WSL como 'mirrored' e tente novamente."
        error_06 = "Para fazer isso, abra o aplicativo 'WSL Settings' e depois a guia 'Networking'."
        error_07 = "Localize a opção 'Networking Mode' e selecione 'Mirrored'."
        error_08 = "O script não conseguiu listar os discos."
        error_09 = "Isso geralmente é causado por um repositório WMI corrompido."
        error_10 = "Faça uma pesquisa na web por '0x80041031,Get-Disk' para encontrar soluções."
        error_11 = "O WSL não está disponível neste computador."
        error_12 = "Unidades USB e leitores de cartão SD não são suportados pelo PSBBN Launcher for Windows."
  }

  spa = @{
        prompt_01 = "Debe reiniciar su equipo para aplicar las funciones recién instaladas."
        prompt_02 = "Una vez que haya reiniciado, simplemente ejecute este script de nuevo."
        prompt_03 = "Está a punto de reiniciar su PC. Guarde su trabajo, escriba 'restart' y presione ENTER."
        prompt_04 = "La distribución de WSL le pedirá que configure un nombre de usuario y una contraseña."
        prompt_05 = "El nombre de usuario debe comenzar con una letra minúscula y contener solo letras y números."
        prompt_06 = "Debe establecer una contraseña."
        prompt_07 = "Una vez completado esto, puede escribir 'exit' y presionar ENTER para continuar."
        prompt_08 = "Lista de discos disponibles:"
        prompt_09 = "Seleccione un disco para PSBBN introduciendo un número o presione 'r' para actualizar la lista."
        prompt_10 = "Entrada no válida. Inténtelo de nuevo."
        prompt_11 = "Número de disco seleccionado:"
        prompt_12 = "La siguiente ruta se utilizó anteriormente:"
        prompt_13 = "¿Desea seguir utilizándola?"
        prompt_14 = "A continuación, se le pedirá que seleccione o cree una carpeta en su PC (por ejemplo, C:\\PSBBN)."
        prompt_15 = "Esta carpeta es para todos los juegos, música, vídeos y archivos de imagen que planea instalar."
        prompt_16 = "Se ha seleccionado la siguiente ruta:"
        prompt_17 = "Antes de continuar, puede añadir sus juegos y otros archivos multimedia a esta carpeta:"
        prompt_18 = "Consulte el archivo Readme de PSBBN Definitive Project para obtener más información."
        prompt_19 = "Se ha seleccionado una unidad de red, por lo que debe montarse. Se le solicitará su contraseña de Linux."
        prompt_20 = "La unidad de red debe desmontarse. Se le solicitará su contraseña de Linux."
        prompt_21 = "¡Disfrute explorando PSBBN!"

        warn_01 = "PSBBN requiere un disco con una capacidad mínima de 32 GB."
        warn_02 = "La virtualización no está habilitada. Es necesaria para ejecutar los scripts de PSBBN."
        warn_03 = "Si tiene una CPU AMD, habilite SVM en su BIOS."
        warn_04 = "Si tiene una CPU Intel, habilite VT-x en su BIOS."
        warn_05 = "Consulte el manual de su placa base si tiene dificultades para encontrar esta configuración."
        warn_06 = "No debe almacenar sus archivos en el sistema de archivos de Linux."
        warn_07 = "Cree una carpeta en su disco de Windows y coloque allí sus archivos ISO y otros archivos."
        warn_08 = "Una vez hecho esto, puede ejecutar este script de nuevo y seleccionar la nueva carpeta."
        warn_09 = "No se seleccionó ninguna carpeta. Vuelva a ejecutar este script y elija una carpeta."

        error_01 = "Su versión de Windows no está actualizada."
        error_02 = "Se requiere una compilación superior a la 19041."
        error_03 = "El script no pudo instalar Git y, por lo tanto, no puede continuar."
        error_04 = "Compruebe su conexión a Internet e intente ejecutar el script de nuevo."
        error_05 = "Si el problema persiste, intente configurar el modo de red de WSL en 'mirrored' y vuelva a intentarlo."
        error_06 = "Para ello, abra la aplicación 'WSL Settings' y luego la pestaña 'Networking'."
        error_07 = "Debería ver allí la opción 'Networking Mode'. Seleccione 'Mirrored'."
        error_08 = "El script no pudo enumerar los discos."
        error_09 = "Esto suele deberse a un repositorio WMI dañado."
        error_10 = "Realice una búsqueda web de '0x80041031,Get-Disk' para encontrar soluciones."
        error_11 = "WSL no está disponible en este ordenador."
        error_12 = "Las unidades USB y los lectores de tarjetas SD no son compatibles con el lanzador PSBBN para Windows."
  }
}

# --- Simple text function ---
function T($key) {
    if ($TEXT[$winLang].ContainsKey($key)) {
        return $TEXT[$winLang][$key]
    }
    return $TEXT["eng"][$key]
}

function main {
  # set the console size so it matches the other scripts
  $host.UI.RawUI.WindowSize = New-Object `
    -TypeName System.Management.Automation.Host.Size `
    -ArgumentList ($consoleWidth, $consoleHeight)

  $PSDefaultParameterValues['*:Encoding'] = 'utf8'

  clear
  printTitle
  Write-Host "Prepare Windows to run the PSBBN scripts.`n"
  
  # check the minimum windows build version necessary for wsl
  $buildNumber = [System.Environment]::OSVersion.Version.Build
  if ($buildNumber -lt 19041) {
    Write-Host "
    ❌ $(T "error_01")
    $(T "error_02")
    " -ForegroundColor Red
    Exit
  }

  # check if mandatory windows features are enabled
  Write-Host "Checking if the mandatory features are enabled..."
  # enable WSL as needed
  checkAndEnableFeature("Microsoft-Windows-Subsystem-Linux")
  # enable Hyper V as needed
  checkAndEnableFeature("HypervisorPlatform")
  # enable Virtual Maching Platform as needed
  checkAndEnableFeature("VirtualMachinePlatform")

  # detect if virtualization is enabled in BIOS
  detectVirtualization

  if ($isRestartRequired) {
    Write-Host "
    $(T "prompt_01")
    $(T "prompt_02")
" -ForegroundColor Yellow
    do {
      clearLines(1)
      $keyPressed = Read-Host "⚠️ $(T 'prompt_03')"
      $keyPressed = $keyPressed.ToLower()
    } while ($keyPressed -ne 'restart')

    if ($keyPressed -eq 'restart') {
      Restart-Computer
    }
    Exit
  }

  # check if wsl exists
  if (-Not (Get-Command wsl -errorAction SilentlyContinue)) {
    Write-Host "❌ $(T "error_11")" -ForegroundColor Red
    Exit
  }

  # fetch the latest wsl update
  Write-Host "Check the latest WSL updates...`t`t`t" -NoNewline
  $null = wsl --update --web-download
  $null = wsl --install --no-distribution
  printOK

  # check if a wsl distro is installed already
  $isWslInstalled = wsl --list | Select-String -SimpleMatch -Quiet $wslLabel
  if (-Not ($isWslInstalled)) {
    Write-Host "`n$(T 'prompt_04')" -ForegroundColor Yellow
    Write-Host "⚠️ $(T 'prompt_05')" -ForegroundColor Red
    Write-Host "⚠️ $(T 'prompt_06')" -ForegroundColor Red
    Write-Host "$(T 'prompt_07')`n" -ForegroundColor Yellow
    Write-Host "------- Linux magic starts ---------"

    wsl --install --distribution Debian --version 2 --name $wslLabel
  } else {
    Write-Host "The WSL distro is already present, skipping.`t" -NoNewline
    printOK
  }

  # install git if it is missing
  wsl -d $wslLabel -- type git `&`> /dev/null `|`| `(sudo apt update `&`& sudo apt -y install git`)

  # check that git is properly installed before continuing. Some network configurations can cause apt to fail to reach the repos
  if (-Not (wsl -d $wslLabel -- type git `2`> /dev/null)) {
    Write-Host "
    ❌ $(T 'error_03')
    $(T 'error_04')
    $(T 'error_05')
    $(T 'error_06')
    $(T 'error_07')
    " -ForegroundColor Red
    Exit
  }
  
  # if a folder with the previous name of the git repository exists,
  # rename it and move the git remote origin to the new url
  wsl -d $wslLabel --cd "~" -- [ -d ./PSBBN-Definitive-English-Patch ] `
    `&`& `( `
      mv ./PSBBN-Definitive-English-Patch ./PSBBN-Definitive-Project `
      `&`& cd PSBBN-Definitive-Project/ `
      `&`& git remote set-url origin $gitRepo `
    `)

  # clone the PSBBN repo into ~, or move an existing clone onto $gitRepo/$gitBranch.
  # An existing clone was made by an earlier version of this script and still has
  # upstream as its origin, so the remote is repointed before the fetch; without
  # that the fetch asks upstream for a branch it does not have. checkout -B forces
  # the branch to what was just fetched, which also covers a clone sitting on main.
  Write-Host
  wsl -d $wslLabel --cd "~" -- [ -d PSBBN-Definitive-Project/.git ] `
    `&`& `( `
      cd PSBBN-Definitive-Project/ `
      `&`& git remote set-url origin $gitRepo `
      `&`& git fetch origin $gitBranch `
      `&`& git checkout -B $gitBranch origin/$gitBranch `
    `) `
    `|`| git clone -b $gitBranch $gitRepo

  # the line above is a shell || chain: when the update path fails, the clone
  # fallback fails too because the folder is already there, and the toolkit would
  # then be run from whatever stale tree is in ~. Confirm the branch before that.
  $repoBranch = (wsl -d $wslLabel --cd "~/PSBBN-Definitive-Project" -- git rev-parse --abbrev-ref HEAD) -join ""
  if ($repoBranch.Trim() -ne $gitBranch) {
    Write-Host "
    Could not put ~/PSBBN-Definitive-Project on branch '$gitBranch'.
    It is on '$repoBranch'.
    Delete it inside WSL and run this script again:
      wsl -d $wslLabel -- rm -rf ~/PSBBN-Definitive-Project
    " -ForegroundColor Red
    Exit
  }

  if (-Not ($isWslInstalled)) {
    Write-Host "------- Linux magic finishes ---------`n"
  }

  # prompt user to choose a disk
  diskPicker

  # mount the disk
  mountDisk

  # give the user the opportunity to put games/homebrew in the PSBBN folder
  $path = getTargetPath
  $wslPath = prepareWslPath($path)
  
  explorer $path
  Write-Host
  pause
  clear

  # run PSBBN regular steps
  wsl -d $wslLabel --cd "~/PSBBN-Definitive-Project" -- `
    env SYS_LANG="$winLang" `
    ./PSBBN-Definitive-Patch.sh -wsl $global:diskList[$selectedDisk].SerialNumber $wslPath

  # clear the terminal to get rid of the wsl-run scripts
  clear
  printTitle

  # unmount the target path if needed (in case of network drive)
  unmountTargetPath

  # unmount the disk before exiting
  unmountDisk

  # ensures wsl doesnt run out of resources if this script is ran repeatedly

  $wslDistrosCount = ((wsl --list --quiet) | Where-Object { $_.Trim() -ne "" }).Count
  if ($wslDistrosCount -eq 1) {
    wsl --shutdown
  } elseif ($wslDistrosCount -gt 1) {
    wsl --terminate $wslLabel
  }

  Write-Host "`n$(T 'prompt_21')`n"  -ForegroundColor Green
}

# print colored `[ OK ]`
function printOK {
  Write-Host "    `t`t[ $e[92mOK$e[0m ]"
}

# print colored `[ NG ]`
function printNG {
  Write-Host "    `t`t[ $e[91mNG$e[0m ]"
}

# print colored `[ Restart required ]`
function printRestartRequired {
  Write-Host "    `t`t[ $e[93mRestart required$e[0m ]"
}

# takes a feature as parameter and enable it if needed
function checkAndEnableFeature ($featureName) {
  $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName
  if (($null -ne $feature.FeatureName) -and ($feature.State -ne "Enabled")) {
    Write-Host "  └ Enabling" $feature.DisplayName "..." -NoNewline;
    $enabled = Enable-WindowsOptionalFeature -Online -FeatureName $feature.FeatureName -All -NoRestart -WarningAction:SilentlyContinue
    if ($enabled.RestartNeeded) {
      $global:isRestartRequired = $true
      printRestartRequired
    } else {
      printOK
    }
  } elseif ($feature.State -eq "Enabled"){
    Write-Host "  └" $feature.DisplayName 'already enabled.' -NoNewline
    printOK
  }
}

# prints the big psbbn logo and the version number
function printTitle {
  Write-Host "
 ______  _________________ _   _  ______      __ _       _ _   _            ______          _           _   
 | ___ \/  ___| ___ \ ___ \ \ | | |  _  \    / _(_)     (_) | (_)           | ___ \        (_)         | |  
 | |_/ /\ `--. | |_/ / |_/ /  \| | | | | |___| |_ _ _ __  _| |_ ___   _____  | |_/ / __ ___  _  ___  ___| |_ 
 |  __/  `--. \  ___ \ ___ \ . `  | | | | / _ \  _| | '_ \| | __| \ \ / / _ \ |  __/ '__/ _ \| |/ _ \/ __| __|
 | |    /\__/ / |_/ / |_/ / |\  | | |/ /  __/ | | | | | | | |_| |\ V /  __/ | |  | | | (_) | |  __/ (__| |_ 
 \_|    \____/\____/\____/\_| \_/ |___/ \___|_| |_|_| |_|_|\__|_| \_/ \___| \_|  |_|  \___/| |\___|\___|\__|
                                                                                          _/ |              
                                                                                         |__/               

                                            Created by CosmicScale
                                                     ---
                                          Launcher for Windows v$version
                                               Written by Yornn

"
}

# display the available disks and prompt user for choice
function diskPicker {
  # store the current cursor position to help clear the console upon refreshing the list of disks
  $lineStart = $Host.UI.RawUI.CursorPosition.Y
  
  # verify that winwmgt is working properly
  winmgmt /verifyrepository

  # list available disks and pick the one to be mounted
  Write-Host "`n$(T 'prompt_08')"
  try {
    $global:diskList = Get-Disk | Sort -Property Number
  }
  catch {
    Write-Host "
    ❌ $(T 'error_08')
    $(T 'error_09')
    $(T 'werror_10')
    " -ForegroundColor Red
    Exit
  }
  $disksExtras = detectDisksExtras
  $global:diskList | Format-Table -AutoSize -Property `
    Number, `
    @{Label="Name";Expression={$_.FriendlyName}}, `
    @{Label="Size";Expression={("{0:N2}" -f ($_.Size / 1GB)).ToString() + " GB"}}, `
    SerialNumber, `
    @{Label="";Expression={$disksExtras[$_.Number]}}
  
  if (($global:diskList | Where-Object -FilterScript {isTooSmall($_)}).Count -gt 0) {
    Write-Host "ℹ️ $(T 'warn_01')`n" -ForegroundColor Yellow
  }

  $selectedDisk = handleDiskSelection

  if ($selectedDisk -eq "r") {
    clearLines($Host.UI.RawUI.CursorPosition.Y - $lineStart)
    diskPicker
  } else {
    $global:selectedDisk = $selectedDisk
  }
}

# handles the input logic of the diskpicker
# this function calls itself recursively as long an invalid input is provided
function handleDiskSelection {
  $selectedDisk = -1
  # generate a list of disk number to validate user input
  $availableNumbers = $global:diskList `
    | Where-Object -FilterScript {-Not (isTooSmall($_))} `
    | Foreach-Object {$_.Number}

  Write-Host "$(T 'prompt_09')`n"
  $promptMessage = " "
  $validInput = $false
  do {
    clearLines(1)
    $input = Read-Host "$promptMessage"
    $input = $input.ToLower()

    if (-Not $validInput) {
      $promptMessage = "$e[91m$(T 'prompt_10')$e[0m"
    }

    # it is necessary to check if $input is empty first, or ($input -in $availableNumbers) will return true for some reason
    $validInput = $input -And (($input -in $availableNumbers) -Or ($input -eq "r"))
  } while (-Not $validInput)

  $selectedDisk = $input

  clearLines(1)
  Write-Host "$(T 'prompt_11') $selectedDisk"

  return $selectedDisk
}

# detects if bios-level virtualization is enabled or not, and display messages
function detectVirtualization {
  Write-Host "Checking if virtualization is enabled in BIOS..." -NoNewline

  $propertyName = "HyperVRequirementVirtualizationFirmwareEnabled"
  $property = Get-ComputerInfo -property $propertyName

  # the property is null if the feature is enabled, false otherwise
  if ($property.$propertyName -eq $false) {
    printNG
    Write-Host "`n
    ⚠️ $(T 'warn_02')
    $(T 'warn_03')
    $(T 'warn_04')
    $(T 'warn_05')
    " -ForegroundColor Yellow
    Exit
  } else {
    printOK
  }
}

# set the disk offline and then mount it to WSL
# offline is necessary otherwise windows processes might prevent wsl from mounting
function mountDisk {
  $deviceName = "\\.\PHYSICALDRIVE$global:selectedDisk"
  Write-Host "`nMounting $deviceName on wsl...`t`t" -NoNewline
  $null = Set-Disk $global:selectedDisk -isOffline $true -errorAction SilentlyContinue
  $mountOut = wsl -d $wslLabel --mount $deviceName --bare
  handleMountOutput($mountOut)
}

# unmount the disk and then set the disk back online
function unmountDisk {
  $deviceName = "\\.\PHYSICALDRIVE$global:selectedDisk"
  Write-Host "Unmounting $deviceName...`t`t" -NoNewline
  $unmountOut = wsl -d $wslLabel --unmount $deviceName
  Set-Disk $global:selectedDisk -isOffline $false
  handleMountOutput($unmountOut)
}

# handles the error code returned by `wsl --mount` or wsl --unmount` and display human friendly messages
function handleMountOutput ($mountOut) {
  if ($mountOut -like "*Wsl/Service/AttachDisk/MountDisk/WSL_E_DISK_ALREADY_ATTACHED*") {
    # in the case where the disk was already attached, we just carry on and treat it as a happy path
    printOK
    Write-Host "The disk was already mounted." -ForegroundColor Green
    return
  } elseif ($mountOut -like "*Wsl/Service/DetachDisk/ERROR_FILE_NOT_FOUND*") {
    # in the case where the disk was already detached, we just carry on and treat it as a happy path
    printOK
    Write-Host "The disk was already unmounted." -ForegroundColor Green
    return
  } elseif ($mountOut -like "*Wsl/Service/AttachDisk/MountDisk/*0x8007000f*") {
    # attempting to mount a sdcard reader will return this error
    printNG
    Write-Host "❌ $(T 'error_12')" -ForegroundColor Red
    Exit
  } elseif ($mountOut -like "*Error code*") {
    printNG
    Write-Host $mountOut -ForegroundColor Red
    Exit
  }
  printOK
}

# checks if the script is running as admin, and if not launches itself in powershell instance running as admin
function restartAsAdminIfNeeded {
  if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # already running as admin, so we just carry on
    return
  }

  # if powershell 7 is installed, launch that one instead of 5.1
  $shell = "powershell"
  if (Get-Command pwsh -errorAction SilentlyContinue) {
    $shell = "pwsh"
  }

  # relaunch the script as admin, this should trigger a UAC prompt
  Start-Process $shell -Verb RunAs -ArgumentList "-NoLogo -NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`""

  # close the initial non-admin shell to avoid confusion
  Exit
}

# handles the path picker and return a valid windows path as a string
function getTargetPath {
  # if a previously used path exists, use that in the folder picker, otherwise use "Desktop"
  $desktopDirectory = [Environment]::GetFolderPath('Desktop')
  $initialDirectory = $desktopDirectory
  $isPresetPath = $false
  if (Test-Path ".\$pathFilename" -PathType Leaf) {
    $initialDirectory = Get-Content -Path ".\$pathFilename"
    $isPresetPath = $true

    # check that the path in path.cfg still exists, if not default to "Desktop"
    if (-Not (Test-Path $initialDirectory -PathType Container)) {
      $initialDirectory = $desktopDirectory
      $isPresetPath = $false
    }
  }

  # if the path is already set, ask if the user wants to re-use it
  if ($isPresetPath) {
    Write-Host "`n$(T 'prompt_12') " -NoNewLine
    Write-Host "$initialDirectory`n" -ForegroundColor Green
    do {
      clearLines(1)
      $keyPressed = Read-Host "$(T 'prompt_13') (y/n)"
      $keyPressed = $keyPressed.ToLower()
    } while ($keyPressed -ne 'y' -and $keyPressed -ne 'n')

    if ($keyPressed -eq 'y') {
      preventsPickingWslPath($initialDirectory)
      return $initialDirectory
    }
  }

  Write-Host "`n$(T 'prompt_14')" -ForegroundColor Yellow
  Write-Host "`n$(T 'prompt_15')`n" -ForegroundColor Yellow

  pause

  # prepare and then open the folder picker
  Add-Type -AssemblyName System.Windows.Forms
  $pathSelection = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    InitialDirectory = $initialDirectory
    CheckFileExists = 0
    ValidateNames = 0
    FileName = "Choose Folder"
  }
  $result = $pathSelection.ShowDialog()

  if($result -ne "OK") {
    Write-Host "⚠️ $(T 'warn_09')" -ForegroundColor Yellow
    Exit
  }

  $pickedPath = Split-Path -Parent $pathSelection.FileName

  preventsPickingWslPath($pickedPath)

  # create default folders if missing
  $defaultFolders.ForEach({
    if (-Not (Test-Path -Path "$pickedPath\$PSItem")) {
      New-Item -Path $pickedPath -Name $PSItem -ItemType Directory | Out-Null
    }
  })

  Write-Host "`n$(T 'prompt_16') $pickedPath" -ForegroundColor Green
  Write-Host "`n$(T 'prompt_17')" -ForegroundColor Yellow
  Write-Host "
    📀 PS2 DVD → /DVD (.iso, .zso)
    💿 PS2 CD → /CD (.bin+.cue, .iso, .zso)
    💿 PS1 → /POPS (.bin+.cue, .VCD)
    🎮 POPStarter → /POPS (SB.*.ELF)
    🛠️ Homebrew → /APPS (.elf, SAS .psu)
    🎵 Music → /music (.mp3, .m4a, .flac, .ogg)
    🎬 Video → /movie (.mp4, .m4v, .mkv, .vob, .mpg, ...)
    🖼️ Images → /photo (.jpg, .png, .tif, .gif, .bmp, .webp, ...)
" -ForegroundColor Yellow
Write-Host "`n$(T 'prompt_18')" -ForegroundColor Yellow
Write-Host "https://github.com/CosmicScale/PSBBN-Definitive-Project`n" -ForegroundColor Yellow

  # store the selected path to re-use next time the script is ran
  New-Item -Path "." -Name $pathFilename -ItemType "file" -Value $pickedPath -Force | Out-Null

  return $pickedPath
}

# clears $count lines with spaces and move the cursor back
function clearLines ($count) {
  $currentLine  = $Host.UI.RawUI.CursorPosition.Y
  $consoleWidth = $Host.UI.RawUI.BufferSize.Width

  $i = 0
  for ($i; $i -le $count; $i++) {
      [Console]::SetCursorPosition(0,($currentLine - $i))
      [Console]::Write("{0,-$consoleWidth}" -f " ")
  }
  [Console]::SetCursorPosition(0,($CurrentLine - $count))
}

# for each disk, generate a message to be displayed in the diskPicker list's last column
function detectDisksExtras {
  # a keyed array of <(int) diskNumber, (string) messages>
  $messages = @{}

  $global:diskList | ForEach-Object {
    $message = "   "
    $diskNumber = $_.Number

    # walks through each partition -> volume to find which disks have volumes named $oplVolumeName
    $null = Get-Partition -disknumber $diskNumber -errorAction SilentlyContinue | ForEach-Object {
      Get-Volume -partition $_ | ForEach-Object {
        $_.FileSystemLabel.GetType()
        if ($_.FileSystemLabel -eq $oplVolumeName) {
          $message = "$e[92mPSBBN detected$e[0m"
        }
      }
    }

    # PSBBN requires disk with at least 32 GB
    if (isTooSmall($_)) {
      $message = "$e[91mInsufficient size$e[0m"
    }

    $messages.Add($diskNumber, $message)
  }

  return $messages
}

function isTooSmall ($item) {
  return ($item.Size / 1GB) -lt $minimumDiskSize
}

function prepareWslPath ($windowsPath) {
  $wslPath = ''
  
  # covers basic drive letters
  if ($windowsPath -match '(?<driveLetter>.):\\(?<path>.+)?') {
    $driveLetter = $Matches.driveLetter.ToLower()
    $path = ""
    if ($Matches.path) {
      $path = $Matches.path.Replace("\", "/")
    }
    $wslPath = "/mnt/$driveLetter/$path"
  }
  # covers network paths (e.g. samba drives)
  elseif ($windowsPath -match '\\\\(?<host>[0-9a-zA-Z._-]+)\\(?<path>.+)') {
    $wslPath = $networkDriveMountpoint
    
    # network drives are not mounted by default, so manually mount the selected path
    Write-Host "$(T 'prompt_19')" -ForegroundColor Yellow
    wsl -d $wslLabel --cd "~" -- mountpoint -q $networkDriveMountpoint `|`| `( `
      sudo mkdir $networkDriveMountpoint `&`> /dev/null `; `
      sudo mount -t drvfs `'$windowsPath`' $networkDriveMountpoint `
    `)
    $global:isDriveMounted = $true
    Write-Host "Network drive mounted.`t`t" -NoNewLine
    printOK
  }

  return $wslPath
}

function unmountTargetPath {
  if ($global:isDriveMounted) {
    Write-Host "$(T 'prompt_20')" -ForegroundColor Yellow
    wsl -d $wslLabel --cd "~" -- sudo umount $networkDriveMountpoint
    $global:isDriveMounted = $false
    Write-Host "Network drive unmounted.`t`t" -NoNewLine
    printOK
  }
}

# prevents the user from picking a wsl filesystem location
function preventsPickingWslPath ($path) {
  if ($path -like '\\wsl.localhost\*') {
    unmountDisk
    Write-Host "
    ⚠️ $(T 'warn_06')
    $(T 'warn_07')
    $(T 'warn_08')
    $(T 'warn_09')
    " -ForegroundColor Yellow
    Exit
  }
}

restartAsAdminIfNeeded

# necessary to ensure the CWD is where the script is located, in case the script was restarted as admin
cd $PSScriptRoot

if ($LogsEnabled) {
  try { $null = Start-Transcript -Path ".\psbbn-windows-launcher.log" }  catch {}
  try {
    main
  } finally {
    try { $null = Stop-Transcript } catch {}
  }
} else {
  main
}