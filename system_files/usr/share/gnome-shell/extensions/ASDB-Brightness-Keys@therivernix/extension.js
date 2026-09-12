import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const BRIGHTNESS_UP = 'screen-brightness-up';
const BRIGHTNESS_DOWN = 'screen-brightness-down';
const OSD_ICON = 'display-brightness-symbolic';

/**
 * Find asdbctl in PATH, with a fallback to Cargo's default per-user location.
 */
function findAsdbctl() {
    const path = GLib.find_program_in_path('asdbctl');
    if (path)
        return path;

    const cargoPath = `${GLib.get_home_dir()}/.cargo/bin/asdbctl`;
    if (GLib.file_test(cargoPath, GLib.FileTest.IS_EXECUTABLE))
        return cargoPath;

    return null;
}

/**
 * Show GNOME's native brightness OSD.
 *
 * GNOME 49+ exposes showAll(icon, label, level, maxLevel), while GNOME 45-48
 * use show(monitorIndex, icon, label, level, maxLevel). Capability detection
 * keeps the extension compatible with both APIs.
 *
 * level is a value from 0.0 to 1.0. Passing null falls back to an icon-only OSD.
 */
function showBrightnessOsd(level) {
    try {
        const icon = new Gio.ThemedIcon({name: OSD_ICON});
        if (typeof Main.osdWindowManager.showAll === 'function') {
            Main.osdWindowManager.showAll(
                icon,
                null,
                level,
                1.0
            );
            return;
        }

        // GNOME 45-48: -1 means show on all monitors.
        Main.osdWindowManager.show(
            -1,
            icon,
            null,
            level,
            1.0
        );
    } catch (error) {
        console.error(`ASDB Brightness Keys: could not show brightness OSD: ${error}`);
    }
}

/**
 * Parse a brightness percentage from `asdbctl get` output.
 *
 * asdbctl documents `get` as returning the current brightness in percent.
 * Accept both a bare number (e.g. "50") and text containing a percentage
 * (e.g. "Brightness: 50%") so minor output-format changes remain harmless.
 */
function parseBrightnessPercent(output) {
    if (!output)
        return null;

    // asdbctl get returns output such as:
    //   brightness 50
    // Remove the textual prefix first, then parse the numeric level.
    // This mirrors the parsing used by the existing Studio Display slider
    // extension and ensures GNOME receives a non-null level, which is what
    // makes the native OSD render its horizontal brightness slider.
    const normalized = output
        .trim()
        .replace(/^brightness\s*/i, '')
        .replace(/%\s*$/, '')
        .trim();

    const level = Number.parseFloat(normalized);
    if (Number.isFinite(level))
        return Math.max(0, Math.min(100, level));

    return null;
}

/**
 * Query the current Studio Display brightness and update GNOME's OSD.
 */
function queryBrightnessAndShowOsd(asdbctl) {
    try {
        const process = Gio.Subprocess.new(
            [asdbctl, 'get'],
            Gio.SubprocessFlags.STDOUT_PIPE |
            Gio.SubprocessFlags.STDERR_PIPE
        );

        process.communicate_utf8_async(null, null, (proc, result) => {
            try {
                const [, stdout, stderr] = proc.communicate_utf8_finish(result);

                if (!proc.get_successful()) {
                    console.error(
                        `ASDB Brightness Keys: asdbctl get failed: ` +
                        `${stderr?.trim() || 'unknown error'}`
                    );
                    // The action itself succeeded; still show an icon-only OSD.
                    showBrightnessOsd(null);
                    return;
                }

                const percent = parseBrightnessPercent(stdout?.trim());
                const level = percent === null ? null : percent / 100;
                showBrightnessOsd(level);

                if (percent !== null) {
                    console.debug(
                        `ASDB Brightness Keys: current brightness: ${percent}%`
                    );
                } else {
                    console.debug(
                        `ASDB Brightness Keys: could not parse brightness from asdbctl get: ` +
                        `${stdout?.trim() || '(empty)'}`
                    );
                }
            } catch (error) {
                console.error(
                    `ASDB Brightness Keys: error reading asdbctl get: ${error}`
                );
                showBrightnessOsd(null);
            }
        });
    } catch (error) {
        console.error(
            `ASDB Brightness Keys: could not run asdbctl get: ${error}`
        );
        showBrightnessOsd(null);
    }
}

/**
 * Run `asdbctl up` or `asdbctl down` asynchronously, then query the resulting
 * brightness and show the native GNOME brightness HUD with the new level.
 */
function runAsdbctl(direction) {
    const asdbctl = findAsdbctl();
    if (!asdbctl) {
        console.error('ASDB Brightness Keys: asdbctl was not found');
        return;
    }

    try {
        const process = Gio.Subprocess.new(
            [asdbctl, direction],
            Gio.SubprocessFlags.STDOUT_PIPE |
            Gio.SubprocessFlags.STDERR_PIPE
        );

        process.communicate_utf8_async(null, null, (proc, result) => {
            try {
                const [, stdout, stderr] = proc.communicate_utf8_finish(result);

                if (!proc.get_successful()) {
                    console.error(
                        `ASDB Brightness Keys: asdbctl ${direction} failed: ` +
                        `${stderr?.trim() || 'unknown error'}`
                    );
                    return;
                }

                if (stdout?.trim()) {
                    console.debug(
                        `ASDB Brightness Keys: asdbctl ${direction}: ${stdout.trim()}`
                    );
                }

                // `up`/`down` do the actual hardware change. Query afterwards
                // so the OSD reflects the real resulting Studio Display level.
                queryBrightnessAndShowOsd(asdbctl);
            } catch (error) {
                console.error(
                    `ASDB Brightness Keys: error waiting for asdbctl ${direction}: ${error}`
                );
            }
        });
    } catch (error) {
        console.error(
            `ASDB Brightness Keys: could not run asdbctl ${direction}: ${error}`
        );
    }
}

export default class ASDBBrightnessKeysExtension extends Extension {
    enable() {
        /**
         * GNOME already owns the physical brightness keybindings. Replacing
         * their handlers avoids registering competing accelerators and keeps
         * the hardware keys working reliably.
         */
        this._upHandler = () => {
            console.debug('ASDB Brightness Keys: brightness up pressed');
            runAsdbctl('up');
        };

        this._downHandler = () => {
            console.debug('ASDB Brightness Keys: brightness down pressed');
            runAsdbctl('down');
        };

        Main.wm.setCustomKeybindingHandler(
            BRIGHTNESS_UP,
            Shell.ActionMode.ALL,
            this._upHandler
        );

        Main.wm.setCustomKeybindingHandler(
            BRIGHTNESS_DOWN,
            Shell.ActionMode.ALL,
            this._downHandler
        );

        console.debug('ASDB Brightness Keys: custom brightness handlers installed');
    }

    disable() {
        // Restore GNOME's original handlers when the extension is disabled.
        Main.wm.setCustomKeybindingHandler(
            BRIGHTNESS_UP,
            Shell.ActionMode.NONE,
            null
        );

        Main.wm.setCustomKeybindingHandler(
            BRIGHTNESS_DOWN,
            Shell.ActionMode.NONE,
            null
        );

        this._upHandler = null;
        this._downHandler = null;
    }
}
