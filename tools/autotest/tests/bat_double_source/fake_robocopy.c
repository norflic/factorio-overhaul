/* Faux robocopy.exe (pose dans la racine jetable : cmd le trouve avant celui de System32, car le .bat fait
   cd /d "%~dp0"). Si FAKE_ROBO_FAIL contient le chemin source (1er argument), rend 16 sans rien copier ;
   sinon appelle le vrai robocopy avec les memes arguments et rend son code. */
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <process.h>

int main(int argc, char **argv) {
  const char *fail = getenv("FAKE_ROBO_FAIL");
  if (fail && argc > 1 && _stricmp(argv[1], fail) == 0) { fprintf(stderr, "faux echec robocopy\n"); return 16; }
  char *args[64]; int n = 0;
  static char quoted[64][1100];
  args[n++] = "C:\\Windows\\System32\\robocopy.exe";
  for (int i = 1; i < argc && n < 62; i++) { snprintf(quoted[i], sizeof quoted[i], "\"%s\"", argv[i]); args[n++] = quoted[i]; }
  args[n] = NULL;
  return (int)_spawnv(_P_WAIT, args[0], (const char *const *)args);
}
