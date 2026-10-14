import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

/**
 * Provides a list of wallpapers and an "apply" action that calls the existing
 * switchwall.sh script. Pretty much a limited file browsing service.
 */
Singleton {
    id: root

    property string thumbgenScriptPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/thumbnails/thumbgen-venv.sh`
    property string generateThumbnailsMagickScriptPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/thumbnails/generate-thumbnails-magick.sh`
    property alias directory: folderModel.folder
    readonly property string effectiveDirectory: FileUtils.trimFileProtocol(folderModel.folder.toString())
    property url defaultFolder: Qt.resolvedUrl(`${Directories.home}/.config/dotfiles/wallpapers`)
    property alias folderModel: folderModel // Expose for direct binding when needed
    property string searchQuery: ""
    property var titles: ({})
    property var entries: []
    readonly property var galleryModel: {
        const terms = searchQuery.toLocaleLowerCase().trim().split(/\s+/).filter(Boolean);
        return entries.map(entry => Object.assign({}, entry, { title: displayName(entry.filePath, entry.fileIsDir) }))
            .filter(entry => {
                const searchable = `${entry.title} ${entry.fileName}`.toLocaleLowerCase();
                return terms.every(term => searchable.includes(term));
            })
            .sort((a, b) => Number(b.fileIsDir) - Number(a.fileIsDir) || a.title.localeCompare(b.title));
    }

    FileView {
        id: titleCatalog
        path: Quickshell.shellPath("assets/wallpaper-titles.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.titles = JSON.parse(titleCatalog.text()); }
            catch (error) { console.warn("Invalid wallpaper title catalog:", error); }
        }
    }

    function displayName(path, isDirectory = false) {
        const filename = path.substring(path.lastIndexOf("/") + 1);
        const collection = FileUtils.trimFileProtocol(root.defaultFolder.toString());
        if (!isDirectory && FileUtils.parentDirectory(path) === collection && root.titles[filename])
            return root.titles[filename];
        const stem = isDirectory ? filename : filename.replace(/\.[^.]+$/, "");
        return stem.replace(/[-_]+/g, " ").replace(/\s+/g, " ").trim()
            .replace(/\b\w/g, letter => letter.toLocaleUpperCase());
    }

    function refreshEntries() {
        const items = [];
        for (let i = 0; i < folderModel.count; ++i) {
            items.push({
                fileName: folderModel.get(i, "fileName"),
                filePath: folderModel.get(i, "filePath"),
                fileIsDir: folderModel.get(i, "fileIsDir")
            });
        }
        root.entries = items;
        root.wallpapers = items.filter(item => !item.fileIsDir).map(item => item.filePath);
    }
    readonly property list<string> extensions: [ // TODO: add videos
        "jpg", "jpeg", "png", "webp", "avif", "bmp", "svg"
    ]
    property list<string> wallpapers: [] // List of absolute file paths (without file://)
    readonly property bool thumbnailGenerationRunning: thumbgenProc.running
    property real thumbnailGenerationProgress: 0

    signal changed()
    signal thumbnailGenerated(directory: string)
    signal thumbnailGeneratedFile(filePath: string)

    function load () {} // For forcing initialization
    
    function openFallbackPicker(darkMode = Appearance.m3colors.darkmode) {
        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", darkMode ? "dark" : "light"]);
    }

    function apply(path, darkMode = Appearance.m3colors.darkmode) {
        if (!path || path.length === 0) return;
        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", darkMode ? "dark" : "light", "--image", path]);
        root.changed()
    }

    Process {
        id: selectProc
        property string filePath: ""
        property bool darkMode: Appearance.m3colors.darkmode
        function select(filePath, darkMode = Appearance.m3colors.darkmode) {
            selectProc.filePath = filePath
            selectProc.darkMode = darkMode
            selectProc.exec(["test", "-d", FileUtils.trimFileProtocol(filePath)])
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                setDirectory(selectProc.filePath);
                return;
            }
            root.apply(selectProc.filePath, selectProc.darkMode);
        }
    }

    function select(filePath, darkMode = Appearance.m3colors.darkmode) {
        selectProc.select(filePath, darkMode);
    }

    function randomFromCurrentFolder(darkMode = Appearance.m3colors.darkmode) {
        if (folderModel.count === 0) return;
        const randomIndex = Math.floor(Math.random() * folderModel.count);
        const filePath = folderModel.get(randomIndex, "filePath");
        print("Randomly selected wallpaper:", filePath);
        root.select(filePath, darkMode);
    }

    Process {
        id: validateDirProc
        property string nicePath: ""
        function setDirectoryIfValid(path) {
            validateDirProc.nicePath = FileUtils.trimFileProtocol(path).replace(/\/+$/, "")
            if (/^\/*$/.test(validateDirProc.nicePath)) validateDirProc.nicePath = "/";
            validateDirProc.exec([
                "bash", "-c",
                'if [ -d "$1" ]; then echo dir; elif [ -f "$1" ]; then echo file; else echo invalid; fi',
                "wallpaper-directory", validateDirProc.nicePath
            ])
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const result = text.trim()
                if (result === "dir") {
                    root.directory = Qt.resolvedUrl(validateDirProc.nicePath)
                } else if (result === "file") {
                    root.directory = Qt.resolvedUrl(FileUtils.parentDirectory(validateDirProc.nicePath))
                } else {
                    // Ignore
                }
            }
        }
    }
    function setDirectory(path) {
        validateDirProc.setDirectoryIfValid(path)
    }
    function navigateUp() {
        folderModel.navigateUp()
    }
    function navigateBack() {
        folderModel.navigateBack()
    }
    function navigateForward() {
        folderModel.navigateForward()
    }

    // Folder model
    FolderListModelWithHistory {
        id: folderModel
        folder: Qt.resolvedUrl(root.defaultFolder)
        caseSensitive: false
        nameFilters: root.extensions.map(ext => `*.${ext}`)
        showDirs: true
        showDotAndDotDot: false
        showOnlyReadable: true
        sortField: FolderListModel.Time
        sortReversed: false
        onCountChanged: root.refreshEntries()
        onStatusChanged: if (status === FolderListModel.Ready) root.refreshEntries()
    }

    // Thumbnail generation
    function generateThumbnail(size: string) {
        if (!["normal", "large", "x-large", "xx-large"].includes(size)) throw new Error("Invalid thumbnail size");
        thumbgenProc.directory = root.directory
        thumbgenProc.running = false
        thumbgenProc.command = [
            "bash", "-c",
            '"$1" --size "$3" --machine_progress -d "$4" || "$2" --size "$3" -d "$4"',
            "wallpaper-thumbnails", thumbgenScriptPath, generateThumbnailsMagickScriptPath,
            size, FileUtils.trimFileProtocol(root.directory),
        ]
        // console.log("[Wallpapers] Updating thumbnails with command ", thumbgenProc.command.join(" "))
        root.thumbnailGenerationProgress = 0
        thumbgenProc.running = true
    }
    Process {
        id: thumbgenProc
        property string directory
        stdout: SplitParser {
            onRead: data => {
                // print("thumb gen proc:", data)
                let match = data.match(/PROGRESS (\d+)\/(\d+)/)
                if (match) {
                    const completed = parseInt(match[1])
                    const total = parseInt(match[2])
                    root.thumbnailGenerationProgress = completed / total
                }
                match = data.match(/FILE (.+)/)
                if (match) {
                    const filePath = match[1]
                    root.thumbnailGeneratedFile(filePath)
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            // print("[Wallpapers] Thumbnail generation completed with exit code", exitCode)
            root.thumbnailGenerated(thumbgenProc.directory)
        }
    }

    IpcHandler {
        target: "wallpapers"

        function apply(path: string): void {
            root.apply(path);
        }
    }
}
