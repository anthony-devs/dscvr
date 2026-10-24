import 'package:dscvr/models/library.dart';
import 'package:flutter/widgets.dart';

/// Single source for every icon in the app.
///
/// Glyphs come from the Phosphor icon font (MIT, bundled in assets/fonts).
/// We define IconData directly because phosphor_flutter's wrapper classes
/// extend IconData, which is a final class on current Flutter.
/// Kept as const so release builds can tree-shake the icon fonts.

class Ic {
  Ic._();
  static const recent = IconData(0xe1a0, fontFamily: 'PhosphorRegular');
  static const readingList = IconData(0xe0ea, fontFamily: 'PhosphorRegular');
  static const readingListOn = IconData(0xe0ea, fontFamily: 'PhosphorFill');
  static const discover = IconData(0xe1c8, fontFamily: 'PhosphorRegular');
  static const pinda = IconData(0xe6a2, fontFamily: 'PhosphorRegular');
  static const search = IconData(0xe30c, fontFamily: 'PhosphorRegular');
  static const settings = IconData(0xe272, fontFamily: 'PhosphorRegular');
  static const add = IconData(0xe3d4, fontFamily: 'PhosphorRegular');
  static const edit = IconData(0xe3b4, fontFamily: 'PhosphorRegular');
  static const grid = IconData(0xe464, fontFamily: 'PhosphorRegular');
  static const rows = IconData(0xe5a2, fontFamily: 'PhosphorRegular');
  static const note = IconData(0xe34c, fontFamily: 'PhosphorRegular');
  static const pdf = IconData(0xe702, fontFamily: 'PhosphorRegular');
  static const link = IconData(0xe2e2, fontFamily: 'PhosphorRegular');
  static const video = IconData(0xe4fc, fontFamily: 'PhosphorRegular');
  static const article = IconData(0xe0a8, fontFamily: 'PhosphorRegular');
  static const paper = IconData(0xe62c, fontFamily: 'PhosphorRegular');
  static const library = IconData(0xe758, fontFamily: 'PhosphorRegular');
  static const caretRight = IconData(0xe13a, fontFamily: 'PhosphorRegular');
  static const caretDown = IconData(0xe136, fontFamily: 'PhosphorRegular');
  static const caretLeft = IconData(0xe138, fontFamily: 'PhosphorRegular');
  static const close = IconData(0xe4f6, fontFamily: 'PhosphorRegular');
  static const trash = IconData(0xe4a6, fontFamily: 'PhosphorRegular');
  static const more = IconData(0xe1fe, fontFamily: 'PhosphorRegular');
  static const back = IconData(0xe058, fontFamily: 'PhosphorRegular');
  static const external = IconData(0xe5de, fontFamily: 'PhosphorRegular');
  static const sidebar = IconData(0xec24, fontFamily: 'PhosphorRegular');
  static const menu = IconData(0xe2f0, fontFamily: 'PhosphorRegular');
  static const signOut = IconData(0xe42a, fontFamily: 'PhosphorRegular');
  static const done = IconData(0xe184, fontFamily: 'PhosphorRegular');
  static const check = IconData(0xe182, fontFamily: 'PhosphorRegular');
  static const send = IconData(0xe396, fontFamily: 'PhosphorRegular');
  static const stop = IconData(0xe46c, fontFamily: 'PhosphorRegular');
  static const copy = IconData(0xe1ca, fontFamily: 'PhosphorRegular');
  static const retry = IconData(0xe094, fontFamily: 'PhosphorRegular');
  static const sort = IconData(0xe098, fontFamily: 'PhosphorRegular');
  static const filter = IconData(0xe268, fontFamily: 'PhosphorRegular');
  static const textSize = IconData(0xe6ee, fontFamily: 'PhosphorRegular');
  static const moon = IconData(0xe330, fontFamily: 'PhosphorRegular');
  static const sun = IconData(0xe472, fontFamily: 'PhosphorRegular');
  static const system = IconData(0xe560, fontFamily: 'PhosphorRegular');
  static const chats = IconData(0xe17e, fontFamily: 'PhosphorRegular');
  static const chat = IconData(0xe16e, fontFamily: 'PhosphorRegular');
  static const notebook = IconData(0xe34e, fontFamily: 'PhosphorRegular');
  static const folder = IconData(0xe25a, fontFamily: 'PhosphorRegular');
  static const folderPlus = IconData(0xe258, fontFamily: 'PhosphorRegular');
  static const folderOpen = IconData(0xe256, fontFamily: 'PhosphorRegular');
  static const quote = IconData(0xe660, fontFamily: 'PhosphorRegular');
  static const upload = IconData(0xe4c0, fontFamily: 'PhosphorRegular');
  static const file = IconData(0xe230, fontFamily: 'PhosphorRegular');
  static const globe = IconData(0xe288, fontFamily: 'PhosphorRegular');
  static const home = IconData(0xe2c2, fontFamily: 'PhosphorRegular');
  static const book = IconData(0xe8f2, fontFamily: 'PhosphorRegular');
  static const tune = IconData(0xe434, fontFamily: 'PhosphorRegular');
  static const user = IconData(0xe4c2, fontFamily: 'PhosphorRegular');
  static const email = IconData(0xe214, fontFamily: 'PhosphorRegular');
  static const lock = IconData(0xe2fa, fontFamily: 'PhosphorRegular');
  static const play = IconData(0xe3d2, fontFamily: 'PhosphorRegular');
  static const list = IconData(0xe2f2, fontFamily: 'PhosphorRegular');
  static const arrowRight = IconData(0xe06c, fontFamily: 'PhosphorRegular');
  static const arrowUpRight = IconData(0xe092, fontFamily: 'PhosphorRegular');
  static const warning = IconData(0xe4e2, fontFamily: 'PhosphorRegular');
  static const info = IconData(0xe2ce, fontFamily: 'PhosphorRegular');
  static const hash = IconData(0xe2a2, fontFamily: 'PhosphorRegular');
  static const arrowUp = IconData(0xe08e, fontFamily: 'PhosphorRegular');
  static const arrowUpBold = IconData(0xe08e, fontFamily: 'PhosphorFill');
  static const caretUpDown = IconData(0xe140, fontFamily: 'PhosphorRegular');
  static const pindaFill = IconData(0xe6a2, fontFamily: 'PhosphorFill');
  static const lightning = IconData(0xe2de, fontFamily: 'PhosphorRegular');
  static const scale = IconData(0xe3f0, fontFamily: 'PhosphorRegular');
  static const minus = IconData(0xe326, fontFamily: 'PhosphorRegular');
  static const question = IconData(0xe3ec, fontFamily: 'PhosphorRegular');
  static const share = IconData(0xe416, fontFamily: 'PhosphorRegular');
  static const linkSimple = IconData(0xe2e4, fontFamily: 'PhosphorRegular');
  static const eye = IconData(0xe224, fontFamily: 'PhosphorRegular');
  static const chatCircle = IconData(0xe16c, fontFamily: 'PhosphorRegular');
  static const gitFork = IconData(0xe278, fontFamily: 'PhosphorRegular');
  static const clock = IconData(0xe192, fontFamily: 'PhosphorRegular');
  static const shield = IconData(0xe41e, fontFamily: 'PhosphorRegular');
  static const wallet = IconData(0xe4d0, fontFamily: 'PhosphorRegular');
  static const creditCard = IconData(0xe1d2, fontFamily: 'PhosphorRegular');
  static const googlePay = IconData(0xe4d0, fontFamily: 'PhosphorRegular'); // wallet glyph as proxy
  static const crown = IconData(0xe1d6, fontFamily: 'PhosphorRegular');
  static const star = IconData(0xe458, fontFamily: 'PhosphorRegular');
  static const starFill = IconData(0xe458, fontFamily: 'PhosphorFill');

  static IconData forKind(MaterialKind k) => switch (k) {
        MaterialKind.paper => paper,
        MaterialKind.pdf => pdf,
        MaterialKind.link => article,
        MaterialKind.note => note,
        MaterialKind.youtube => video,
      };
}
