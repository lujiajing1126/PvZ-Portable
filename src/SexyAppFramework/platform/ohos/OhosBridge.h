/*
 * Copyright (C) 2026 Megrez Lu <lujiajing1126@gmail.com>
 *
 * SPDX-License-Identifier: LGPL-3.0-or-later
 *
 * This file is part of PvZ-Portable.
 *
 * PvZ-Portable is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PvZ-Portable is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with PvZ-Portable. If not, see <https://www.gnu.org/licenses/>.
 */

#ifndef __OHOSBRIDGE_H__
#define __OHOSBRIDGE_H__

// Native side of the small NAPI module ("libmain.so") that the ArkTS shell in harmony/ imports.
// SDL3 owns the rest of the ArkTS <-> native plumbing; this only covers what SDL3 doesn't expose.

// Asks the ArkTS shell to terminateSelf() the ability and waits briefly for the process to go away.
// Returning from SDL_main makes SDL call exit(), which HarmonyOS reports as a crash.
void PvzpOhosTerminateApp();

#endif // __OHOSBRIDGE_H__
