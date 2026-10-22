/* Faux factorio.exe pour tester fo-autotest.bat hors jeu (racines jetables du scratchpad).
   --create <zip> : ecrit le zip ; si FAKE_HOLD=<fichier relatif>, lance un enfant detache qui garde
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
    return 0;
  }
  printf("arguments inconnus\n");
  return 1;
}
