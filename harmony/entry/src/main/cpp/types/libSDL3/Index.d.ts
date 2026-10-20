// Mirrors the arguments EntryAbility.ets passes; must match the pinned SDL3 commit (harmony/build-deps.sh).
export const provideArkTSObjects: (ability: object, atManager: object, i18nSystem: object,
  setPointerVisibleSync: Function, imeController: object) => void;
