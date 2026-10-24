"""Builds the preview page: the Flutter app inside an iPhone-sized screen.

usage: make_phone_preview.py <build/web/index.html> <out.html>
On a phone-width viewer the frame drops away and the app fills the screen.
"""
import re, sys

src, out = sys.argv[1], sys.argv[2]
html = open(src).read()
script = re.search(r'<script>(.*)</script>', html, re.S).group(1)
loader, _, _ = script.partition('_flutter.loader.load(')

STATUS_ICONS = '''<svg width="18" height="12" viewBox="0 0 18 12" aria-hidden="true"><rect x="0" y="8" width="3" height="4" rx="1" fill="currentColor"/><rect x="5" y="5.5" width="3" height="6.5" rx="1" fill="currentColor"/><rect x="10" y="3" width="3" height="9" rx="1" fill="currentColor"/><rect x="15" y="0" width="3" height="12" rx="1" fill="currentColor"/></svg>
<svg width="16" height="12" viewBox="0 0 16 12" aria-hidden="true"><path d="M8 2.2c2.4 0 4.6.9 6.3 2.5l1.2-1.3A10.6 10.6 0 0 0 8 .4C5.2.4 2.6 1.5.5 3.4l1.2 1.3A8.8 8.8 0 0 1 8 2.2Zm0 3.6c1.4 0 2.7.5 3.7 1.4l1.2-1.3A7.2 7.2 0 0 0 8 4c-1.8 0-3.5.7-4.9 1.9l1.2 1.3c1-.9 2.3-1.4 3.7-1.4Zm0 3.5c-.6 0-1.2.2-1.6.6L8 11.6l1.6-1.7c-.4-.4-1-.6-1.6-.6Z" fill="currentColor"/></svg>
<svg width="27" height="13" viewBox="0 0 27 13" aria-hidden="true"><rect x="0.5" y="0.5" width="23" height="12" rx="3.5" fill="none" stroke="currentColor" opacity="0.4"/><rect x="2" y="2" width="20" height="9" rx="2.2" fill="currentColor"/><path d="M25 4.5v4c.8-.3 1.3-1.1 1.3-2s-.5-1.7-1.3-2Z" fill="currentColor" opacity="0.4"/></svg>'''

page = '''<title>Mesh Console</title>
<style>
  /* Layout: one iPhone-sized screen centered on a quiet ground; on a phone the
     app fills the screen. The screen's own colors follow the phone's light or
     dark setting, as the app does. */
  :root {
    --ground: #e6e9ef; --note: #4a5468; --frame: #11141b; --frame-edge: #2a303c;
    --screen: #f5f7fb; --screen-ink: #121826; --ring: rgba(10, 115, 99, 0.2); --accent: #0a7363;
  }
  @media (prefers-color-scheme: dark) {
    :root { --screen: #0b1220; --screen-ink: #e8ecf5; --ring: rgba(61, 219, 185, 0.2); --accent: #3ddbb9; }
    :root:not([data-theme="light"]) { --ground: #05070c; --note: #a3aec4; --frame-edge: #343b49; color-scheme: dark; }
  }
  :root[data-theme="dark"] { --ground: #05070c; --note: #a3aec4; --frame-edge: #343b49; color-scheme: dark; }

  html, body { height: 100%; }
  body { margin: 0; background: var(--ground); color: var(--note); }
  .stage {
    box-sizing: border-box; min-height: 100%;
    display: grid; place-items: center; align-content: center; gap: 16px;
    padding-block: 24px; padding-left: 16px; padding-right: 16px;
  }
  .phone {
    /* Always a real iPhone width (390 points); only the height adapts, down
       to an iPhone SE's, so text and buttons sit as they will on a phone. */
    box-sizing: border-box; width: 414px; height: clamp(691px, calc(100dvh - 104px), 868px);
    padding: 12px; border-radius: 64px; background: var(--frame);
    box-shadow: 0 0 0 2px var(--frame-edge), 0 24px 48px -24px rgba(0, 0, 0, 0.45);
  }
  .screen {
    position: relative; height: 100%; overflow: hidden; border-radius: 52px;
    display: flex; flex-direction: column; background: var(--screen); color: var(--screen-ink);
  }
  .status {
    flex: none; height: 54px; display: flex; align-items: center; justify-content: space-between;
    padding: 4px 30px 0 46px; font: 600 17px/1 -apple-system, "SF Pro Text", system-ui, sans-serif;
  }
  .status .icons { display: flex; gap: 6px; align-items: center; }
  .island {
    position: absolute; top: 11px; left: 50%; transform: translateX(-50%);
    width: 124px; height: 36px; border-radius: 20px; background: #000;
  }
  #app { position: relative; flex: 1; min-height: 0; }
  .home { flex: none; height: 30px; display: grid; place-items: center; }
  .home span { width: 136px; height: 5px; border-radius: 3px; background: var(--screen-ink); }
  .note { margin: 0; max-width: 46ch; font: 16px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; text-align: center; text-wrap: balance; }

  #loading { position: absolute; inset: 54px 0 30px; display: grid; place-items: center; }
  #loading .spin {
    width: 28px; height: 28px; border-radius: 50%;
    border: 3px solid var(--ring); border-top-color: var(--accent);
    animation: spin 0.8s linear infinite;
  }
  #loading p { max-width: 30ch; margin: 0; padding-inline: 16px; text-align: center; font: 16px/1.5 system-ui, sans-serif; }
  @keyframes spin { to { transform: rotate(360deg); } }
  @media (prefers-reduced-motion: reduce) { #loading .spin { animation-duration: 2.4s; } }

  /* On a phone: no frame, the app is the screen. */
  @media (max-width: 520px) {
    .stage { display: block; height: 100%; padding: 0; }
    .phone { width: 100%; height: 100%; padding: 0; border-radius: 0; box-shadow: none; background: none; }
    .screen { border-radius: 0; }
    .status, .island, .home, .note { display: none; }
    #loading { inset: 0; }
  }
</style>
<main class="stage">
  <div class="phone" role="region" aria-label="Phone preview of the Mesh app">
    <div class="screen">
      <div class="status" aria-hidden="true"><span>9:41</span><span class="icons">''' + STATUS_ICONS + '''</span></div>
      <div class="island" aria-hidden="true"></div>
      <div id="app"></div>
      <div class="home" aria-hidden="true"><span></span></div>
      <div id="loading" role="status" aria-label="Loading"><div class="spin"></div></div>
    </div>
  </div>
  <p class="note">Phone preview with demo data. Streets appear in the installed app once a Google Maps key is added.</p>
</main>
<script>
''' + loader + '''
  function showError(err) {
    console.error(err);
    const box = document.getElementById('loading');
    if (box) box.innerHTML = '<p>The app could not start in this viewer. See the screenshots in the chat.</p>';
  }
  try {
    _flutter.loader.load({
      onEntrypointLoaded: async function (engineInitializer) {
        try {
          // Runs the app inside the phone screen instead of the whole page.
          const appRunner = await engineInitializer.initializeEngine({
            hostElement: document.getElementById('app'),
          });
          document.getElementById('loading')?.remove();
          await appRunner.runApp();
        } catch (err) { showError(err); }
      }
    });
  } catch (err) { showError(err); }
</script>
'''
open(out, 'w').write(page)
