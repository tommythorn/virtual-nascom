// Author: Peter Jensen

#include <stdio.h>
#ifdef __EMSCRIPTEN__
  #include <emscripten.h>
#endif  
#include <SDL.h>
#include <SDL_ttf.h>

#define DISPLAY_WIDTH    480
#define DISPLAY_HEIGHT   256
#define UI_REFRESH_RATE  60
#define TTF_FONT         "FreeSans.ttf"
#define TTF_FONT_SIZE    20

static SDL_Window   *window;
static SDL_Surface  *screen;
static TTF_Font     *font;
static char infoText[256] = {0};

static int sdlInit() {
  if (SDL_Init(SDL_INIT_TIMER | SDL_INIT_VIDEO) < 0) {
    fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
    return 1;
  }
  atexit(SDL_Quit);

  // Create window
  window = SDL_CreateWindow("SDL Test",
    SDL_WINDOWPOS_UNDEFINED,
    SDL_WINDOWPOS_UNDEFINED,
    DISPLAY_WIDTH, DISPLAY_HEIGHT,
    SDL_WINDOW_RESIZABLE);
  if (window == NULL) {
    fprintf(stderr, "ERROR: Cannot create window: %s\n", SDL_GetError());
    return 1;
  }

  // Create window surface
  screen = SDL_GetWindowSurface(window);

  // Create font
  TTF_Init();
  font = TTF_OpenFont(TTF_FONT, TTF_FONT_SIZE);
  if (font == NULL) {
    fprintf(stderr, "ERROR: Cannot create font\n");
    return 1;
  }

  // Clear the screen
  SDL_FillRect(screen, NULL, 0);
//  SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "linear");

  return 0;
}

static void sdlUpdateText(const char *text) {
  SDL_Surface *surface;
  SDL_Color    color = {255, 255, 255, 0};
  if (screen) {
    SDL_FreeSurface(screen);
    screen = SDL_GetWindowSurface(window);
  }
  SDL_FillRect(screen, NULL, 0);
  surface = TTF_RenderText_Blended_Wrapped(font, text, color, screen->w);  
  SDL_BlitSurface(surface, NULL, screen, NULL);
  SDL_FreeSurface(surface);
}

static int sdlLoop() {
  SDL_Event  event;
  SDL_Keysym key;
  if (SDL_PollEvent(&event)) {
    switch (event.type) {
      case SDL_KEYDOWN:
      //case SDL_KEYUP: 
        key = event.key.keysym;
        printf("scancode: %d, sym: %d, mod:%d\n", key.scancode, key.sym, key.mod);
        sprintf(infoText, "scancode: %d\nsym: %d\nmod:%d", key.scancode, key.sym, key.mod);
        //handle_key_event(event.key.keysym, event.type == SDL_KEYDOWN);
        break;
      case SDL_QUIT:
        return 0;
      default:
        //printf("Unknown event: %d\n", event.type);
        break;
    }
  }
  sdlUpdateText(infoText);
  SDL_UpdateWindowSurface(window);
  return 1;
}

#ifdef __EMSCRIPTEN__
static void emLoop() {
  sdlLoop();
}
#endif

int main(int argc, char **argv) {
  if (sdlInit() != 0) {
    return 1;
  }
#ifdef __EMSCRIPTEN__
    emscripten_set_main_loop(emLoop, -1, 1);
#else
  while (sdlLoop()) {
    SDL_Delay(1000/UI_REFRESH_RATE);
  }
#endif
  return 0;
}
