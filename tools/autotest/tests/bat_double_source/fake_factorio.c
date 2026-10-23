/* Faux factorio.exe pour tester fo-autotest.bat hors jeu (racines jetables du scratchpad).
   --create <zip> : affiche la graine recue (--map-gen-seed) et FO_MAP_SEED (lot INT-GRAINE), ecrit le zip ; si FAKE_HOLD=<fichier relatif>, lance un enfant detache qui garde
   <mods>\factorio-overhaul\<fichier> ouvert sans partage pendant 8 s (rmdir echoue en partie).
   --benchmark <zip> : affiche la version d'info.json de la copie et la presence de marker-old.txt.
   --hold <chemin> <drapeau> : (enfant) ouvre le fichier sans partage, cree le drapeau, dort 8 s. */
#include <windows.h>
#include <stdio.h>
#include <string.h>

static const char *arg_after(int argc, char **argv, const char *k) {
  for (int i = 1; i < argc - 1; i++) if (strcmp(argv[i], k) == 0) return argv[i + 1];
  return NULL;
}

/* Lot S0 (E69) : nombre de --disable-audio recus et lignes de volume du config.ini passe par --config (le faux
   jeu lit le fichier AU MOMENT du lancement : preuve que les volumes a 0 y sont avant le lancement). */
static void print_audio(const char *phase, int argc, char **argv) {
  int n = 0;
  for (int i = 1; i < argc; i++) if (strcmp(argv[i], "--disable-audio") == 0) n++;
  printf("%s : disable-audio x%d\n", phase, n);
  /* Correction du lot S0 : pilote SDL recu dans l'environnement (disk attendu avec le son actif, sortie dans fo-autotest). */
  const char *drv = getenv("SDL_AUDIODRIVER");
  if (drv) printf("%s : env SDL_AUDIODRIVER [%s]\n", phase, drv); else printf("%s : env SDL_AUDIODRIVER ABSENTE\n", phase);
  const char *dsk = getenv("SDL_DISKAUDIOFILE");
  if (dsk) printf("%s : env SDL_DISKAUDIOFILE [%s]\n", phase, dsk); else printf("%s : env SDL_DISKAUDIOFILE ABSENTE\n", phase);
  const char *cfg = arg_after(argc, argv, "--config");
  FILE *f = cfg ? fopen(cfg, "r") : NULL;
  if (!f) { printf("%s : config ABSENT\n", phase); return; }
  char line[512];
  int sound = 0, vols = 0;
  while (fgets(line, sizeof line, f)) {
    line[strcspn(line, "\r\n")] = 0;
    if (strcmp(line, "[sound]") == 0) sound++;
    if (strstr(line, "volume")) { vols++; printf("%s : config %s\n", phase, line); }
  }
  fclose(f);
  printf("%s : config [sound] x%d, %d ligne(s) de volume\n", phase, sound, vols);
}

int main(int argc, char **argv) {
  if (argc >= 4 && strcmp(argv[1], "--hold") == 0) {
    HANDLE h = CreateFileA(argv[2], GENERIC_READ, 0, NULL, OPEN_EXISTING, 0, NULL);
    FILE *f = fopen(argv[3], "w");
    if (f) { fprintf(f, "%s\n", h == INVALID_HANDLE_VALUE ? "echec" : "tenu"); fclose(f); }
    Sleep(8000);
    if (h != INVALID_HANDLE_VALUE) CloseHandle(h);
    return 0;
  }
  const char *mods = arg_after(argc, argv, "--mod-directory");
  const char *create = arg_after(argc, argv, "--create");
  const char *bench = arg_after(argc, argv, "--benchmark");
  if (create) {
    /* Lot INT-GRAINE : la graine recue (valeur qui suit --map-gen-seed), le nombre d'occurrences de l'option
       et le nombre d'arguments (une graine coupee en deux mots changerait argc) ; lu par run.py dans
       create-stdout.txt. */
    const char *seed = arg_after(argc, argv, "--map-gen-seed");
    int nseed = 0;
    for (int i = 1; i < argc; i++) if (strcmp(argv[i], "--map-gen-seed") == 0) nseed++;
    printf("create : map-gen-seed [%s] x%d argc %d\n", seed ? seed : "ABSENT", nseed, argc);
    const char *env = getenv("FO_MAP_SEED");
    if (env) printf("create : env FO_MAP_SEED [%s]\n", env); else printf("create : env FO_MAP_SEED ABSENTE\n");
    print_audio("create", argc, argv);
    FILE *z = fopen(create, "w");
    if (z) { fputs("faux zip\n", z); fclose(z); }
    const char *hold = getenv("FAKE_HOLD");
    if (hold && mods) {
      char target[1024], flag[1024], cmd[4096], self[1024];
      snprintf(target, sizeof target, "%s\\factorio-overhaul\\%s", mods, hold);
      snprintf(flag, sizeof flag, "%s\\..\\hold-flag.txt", mods);
      GetModuleFileNameA(NULL, self, sizeof self);
      snprintf(cmd, sizeof cmd, "\"%s\" --hold \"%s\" \"%s\"", self, target, flag);
      STARTUPINFOA si; PROCESS_INFORMATION pi;
      memset(&si, 0, sizeof si); si.cb = sizeof si;
      if (CreateProcessA(NULL, cmd, NULL, NULL, FALSE, DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP, NULL, NULL, &si, &pi)) {
        CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
        for (int i = 0; i < 50; i++) { if (GetFileAttributesA(flag) != INVALID_FILE_ATTRIBUTES) break; Sleep(100); }
      }
      printf("create : hold %s\n", target);
    }
    printf("create ok\n");
    return 0;
  }
  if (bench && mods) {
    char p[1024], line[512];
    snprintf(p, sizeof p, "%s\\factorio-overhaul\\info.json", mods);
    FILE *f = fopen(p, "r");
    printf("benchmark : info.json ");
    if (f) { while (fgets(line, sizeof line, f)) { char *v = strstr(line, "\"version\""); if (v) printf("%s", v); } fclose(f); }
    else printf("ABSENT\n");
    snprintf(p, sizeof p, "%s\\factorio-overhaul\\marker-old.txt", mods);
    printf("benchmark : marker-old.txt %s\n", GetFileAttributesA(p) != INVALID_FILE_ATTRIBUTES ? "PRESENT" : "absent");
    print_audio("benchmark", argc, argv);
    return 0;
  }
  printf("arguments inconnus\n");
  return 1;
}
