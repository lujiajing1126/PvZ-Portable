import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';

const SAVE_DIR_NAME = 'userdata';
const EXPORT_FILE_NAME = 'pvz-portable-savedata.zip';

// Resource import and save data management, the HarmonyOS counterpart of Android's ResourceImportActivity.
// The app is sandboxed, so everything is copied into the directory the game reads from.
export class GameData {
  private context: common.UIAbilityContext;
  // Must match SDL_GetPrefPath("io.github.wszqkzqk", "PvZPortable") on HarmonyOS, which SDL3 builds from the
  // *application* context's filesDir (the ability context's filesDir is a per-module directory).
  readonly gameDir: string;
  private cacheDir: string;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
    const appContext = context.getApplicationContext();
    this.gameDir = appContext.filesDir + '/PvZPortable';
    this.cacheDir = appContext.cacheDir;
    if (!fs.accessSync(this.gameDir)) {
      fs.mkdirSync(this.gameDir, true);
    }
  }

  hasResources(): boolean {
    return fs.accessSync(this.gameDir + '/main.pak') && isDirectory(this.gameDir + '/properties');
  }

  hasSaveData(): boolean {
    const saveDir = this.gameDir + '/' + SAVE_DIR_NAME;
    return isDirectory(saveDir) && fs.listFileSync(saveDir).length > 0;
  }

  // Resolves to false if the user cancelled the picker.
  async importResourcesZip(): Promise<boolean> {
    const uri = await this.pickZip();
    if (uri === undefined) {
      return false;
    }
    const extracted = await this.extractToTemp(uri);
    try {
      // Accept both "main.pak, properties/..." and a single wrapper directory ("PvZ/main.pak").
      const root = findDirContaining(extracted, 'main.pak');
      if (root === undefined) {
        throw new Error('main.pak not found');
      }
      for (const name of fs.listFileSync(root)) {
        await replacePath(root + '/' + name, this.gameDir + '/' + name);
      }
    } finally {
      await removePath(extracted);
    }
    return true;
  }

  async importSaveZip(): Promise<boolean> {
    const uri = await this.pickZip();
    if (uri === undefined) {
      return false;
    }
    const extracted = await this.extractToTemp(uri);
    try {
      // Exports contain userdata/ at the top; a ZIP of the folder's contents works too.
      const parent = findDirContaining(extracted, SAVE_DIR_NAME);
      const saveRoot = parent !== undefined ? parent + '/' + SAVE_DIR_NAME : extracted;
      await replacePath(saveRoot, this.gameDir + '/' + SAVE_DIR_NAME);
    } finally {
      await removePath(extracted);
    }
    return true;
  }

  async exportSaveZip(): Promise<boolean> {
    const documentPicker = new picker.DocumentViewPicker(this.context);
    const saveOptions = new picker.DocumentSaveOptions();
    saveOptions.newFileNames = [EXPORT_FILE_NAME];
    const uris = await documentPicker.save(saveOptions);
    if (uris.length === 0) {
      return false;
    }

    const tempZip = this.cacheDir + '/' + EXPORT_FILE_NAME;
    await removePath(tempZip);
    const options: zlib.Options = {
      level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION,
      memLevel: zlib.MemLevel.MEM_LEVEL_DEFAULT,
      strategy: zlib.CompressStrategy.COMPRESS_STRATEGY_DEFAULT_STRATEGY
    };
    try {
      // Compressing the directory keeps "userdata/" as the archive's top level, like the Android export.
      await zlib.compressFile(this.gameDir + '/' + SAVE_DIR_NAME, tempZip, options);
      const out = fs.openSync(uris[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        await fs.copyFile(tempZip, out.fd);
      } finally {
        fs.closeSync(out);
      }
    } finally {
      await removePath(tempZip);
    }
    return true;
  }

  private async pickZip(): Promise<string | undefined> {
    const documentPicker = new picker.DocumentViewPicker(this.context);
    const selectOptions = new picker.DocumentSelectOptions();
    selectOptions.maxSelectNumber = 1;
    selectOptions.fileSuffixFilters = ['ZIP|.zip'];
    const uris = await documentPicker.select(selectOptions);
    return uris.length > 0 ? uris[0] : undefined;
  }

  // Copies the picked document into the sandbox and unpacks it; returns the extraction directory.
  private async extractToTemp(uri: string): Promise<string> {
    const tempZip = this.cacheDir + '/import.zip';
    const tempDir = this.cacheDir + '/import';
    await removePath(tempZip);
    await removePath(tempDir);
    fs.mkdirSync(tempDir, true);

    const src = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    try {
      await fs.copyFile(src.fd, tempZip);
    } finally {
      fs.closeSync(src);
    }

    try {
      const options: zlib.Options = {
        level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION,
        memLevel: zlib.MemLevel.MEM_LEVEL_DEFAULT,
        strategy: zlib.CompressStrategy.COMPRESS_STRATEGY_DEFAULT_STRATEGY
      };
      await zlib.decompressFile(tempZip, tempDir, options);
    } catch (e) {
      await removePath(tempDir);
      throw e as Error;
    } finally {
      await removePath(tempZip);
    }
    return tempDir;
  }
}

function isDirectory(path: string): boolean {
  return fs.accessSync(path) && fs.statSync(path).isDirectory();
}

// Returns `dir` or its only subdirectory, whichever directly contains `name`.
function findDirContaining(dir: string, name: string): string | undefined {
  if (fs.accessSync(dir + '/' + name)) {
    return dir;
  }
  const subdirs = fs.listFileSync(dir).filter((entry: string) => isDirectory(dir + '/' + entry));
  if (subdirs.length === 1 && fs.accessSync(dir + '/' + subdirs[0] + '/' + name)) {
    return dir + '/' + subdirs[0];
  }
  return undefined;
}

async function removePath(path: string): Promise<void> {
  if (!fs.accessSync(path)) {
    return;
  }
  if (fs.statSync(path).isDirectory()) {
    await fs.rmdir(path);
  } else {
    await fs.unlink(path);
  }
}

// cacheDir and filesDir are both in the app's el2 sandbox, so a rename moves the data without copying.
async function replacePath(src: string, dest: string): Promise<void> {
  await removePath(dest);
  await fs.rename(src, dest);
}
