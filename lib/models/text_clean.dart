/// Turns the markup that leaks into abstracts and titles into plain, readable text:
/// LaTeX from arXiv ("$a_n$", "\mathbb E", "\sqrt{k}"), and HTML or JATS tags and
/// entities from journal feeds. The original is never changed in storage by this.
library;

const _greek = {
  'alpha': 'α', 'beta': 'β', 'gamma': 'γ', 'delta': 'δ', 'epsilon': 'ε', 'varepsilon': 'ε', 'zeta': 'ζ', 'eta': 'η', 'theta': 'θ',
  'vartheta': 'ϑ', 'iota': 'ι', 'kappa': 'κ', 'lambda': 'λ', 'mu': 'μ', 'nu': 'ν', 'xi': 'ξ', 'pi': 'π', 'varpi': 'ϖ', 'rho': 'ρ',
  'varrho': 'ϱ', 'sigma': 'σ', 'varsigma': 'ς', 'tau': 'τ', 'upsilon': 'υ', 'phi': 'φ', 'varphi': 'φ', 'chi': 'χ', 'psi': 'ψ',
  'omega': 'ω', 'Gamma': 'Γ', 'Delta': 'Δ', 'Theta': 'Θ', 'Lambda': 'Λ', 'Xi': 'Ξ', 'Pi': 'Π', 'Sigma': 'Σ', 'Upsilon': 'Υ',
  'Phi': 'Φ', 'Psi': 'Ψ', 'Omega': 'Ω',
};

const _symbols = {
  'infty': '∞', 'sum': '∑', 'prod': '∏', 'int': '∫', 'oint': '∮', 'partial': '∂', 'nabla': '∇', 'ell': 'ℓ', 'hbar': 'ħ',
  'le': '≤', 'leq': '≤', 'ge': '≥', 'geq': '≥', 'ne': '≠', 'neq': '≠', 'approx': '≈', 'sim': '∼', 'simeq': '≃', 'cong': '≅',
  'equiv': '≡', 'propto': '∝', 'll': '≪', 'gg': '≫', 'to': '→', 'rightarrow': '→', 'leftarrow': '←', 'gets': '←',
  'Rightarrow': '⇒', 'Leftarrow': '⇐', 'leftrightarrow': '↔', 'Leftrightarrow': '⇔', 'mapsto': '↦', 'longrightarrow': '⟶',
  'implies': '⇒', 'iff': '⇔', 'uparrow': '↑', 'downarrow': '↓', 'cdot': '·', 'cdots': '⋯', 'ldots': '…', 'dots': '…', 'vdots': '⋮',
  'times': '×', 'div': '÷', 'pm': '±', 'mp': '∓', 'circ': '∘', 'bullet': '•', 'star': '⋆', 'ast': '∗', 'oplus': '⊕',
  'otimes': '⊗', 'in': '∈', 'notin': '∉', 'ni': '∋', 'subset': '⊂', 'subseteq': '⊆', 'supset': '⊃', 'supseteq': '⊇',
  'cup': '∪', 'cap': '∩', 'emptyset': '∅', 'varnothing': '∅', 'forall': '∀', 'exists': '∃', 'neg': '¬', 'lnot': '¬',
  'land': '∧', 'wedge': '∧', 'lor': '∨', 'vee': '∨', 'perp': '⊥', 'parallel': '∥', 'mid': '|', 'vert': '|', 'Vert': '‖',
  'langle': '⟨', 'rangle': '⟩', 'lceil': '⌈', 'rceil': '⌉', 'lfloor': '⌊', 'rfloor': '⌋', 'angle': '∠', 'degree': '°',
  'prime': '′', 'dagger': '†', 'top': '⊤', 'bot': '⊥', 'sqcup': '⊔', 'setminus': '∖', 'backslash': '\\', 'triangle': '△',
  'Re': 'Re', 'Im': 'Im', 'S': '§', 'P': '¶', 'copyright': '©', 'textbackslash': '\\',
};

const _blackboard = {
  'R': 'ℝ', 'N': 'ℕ', 'Z': 'ℤ', 'Q': 'ℚ', 'C': 'ℂ', 'H': 'ℍ', 'P': 'ℙ', 'E': '𝔼', '1': '𝟙', 'F': '𝔽', 'T': '𝕋', 'S': '𝕊',
};

const _functions = {
  'log', 'ln', 'exp', 'sin', 'cos', 'tan', 'cot', 'sec', 'csc', 'sinh', 'cosh', 'tanh', 'arcsin', 'arccos', 'arctan', 'min', 'max',
  'sup', 'inf', 'lim', 'liminf', 'limsup', 'det', 'dim', 'ker', 'arg', 'argmin', 'argmax', 'deg', 'gcd', 'Pr', 'tr', 'rank', 'mod',
  'sgn', 'diag', 'span', 'var', 'cov',
};

const _sup = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', '+': '⁺', '-': '⁻', '−': '⁻',
  '=': '⁼', '(': '⁽', ')': '⁾', 'n': 'ⁿ', 'i': 'ⁱ', 'T': 'ᵀ', 'k': 'ᵏ', 'x': 'ˣ', 'y': 'ʸ', 'a': 'ᵃ', 'b': 'ᵇ', 'c': 'ᶜ', 'd': 'ᵈ',
  'e': 'ᵉ', 'm': 'ᵐ', 'p': 'ᵖ', 't': 'ᵗ', 'j': 'ʲ', 'r': 'ʳ', 's': 'ˢ', 'q': 'ᵠ', '*': '*', '′': '′',
};

const _sub = {
  '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄', '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉', '+': '₊', '-': '₋', '−': '₋',
  '=': '₌', '(': '₍', ')': '₎', 'a': 'ₐ', 'e': 'ₑ', 'h': 'ₕ', 'i': 'ᵢ', 'j': 'ⱼ', 'k': 'ₖ', 'l': 'ₗ', 'm': 'ₘ', 'n': 'ₙ', 'o': 'ₒ',
  'p': 'ₚ', 'r': 'ᵣ', 's': 'ₛ', 't': 'ₜ', 'u': 'ᵤ', 'v': 'ᵥ', 'x': 'ₓ',
};

const _accents = {'hat': '\u0302', 'widehat': '\u0302', 'tilde': '\u0303', 'widetilde': '\u0303', 'bar': '\u0304', 'overline': '\u0304', 'vec': '\u20D7', 'dot': '\u0307', 'ddot': '\u0308'};

const _wrappers = {
  'text', 'textrm', 'textit', 'textbf', 'textsf', 'texttt', 'textsc', 'mathrm', 'mathbf', 'mathit', 'mathsf', 'mathtt', 'mathcal', 'mathscr',
  'mathfrak', 'boldsymbol', 'bm', 'operatorname', 'emph', 'mbox', 'hbox', 'rm', 'bf', 'it', 'cal', 'displaystyle', 'textstyle', 'scriptstyle',
  'underline', 'cancel', 'mathop', 'mathrel', 'mathbin',
};

/// First balanced {...} group starting at [i] (which must be '{'). Returns the inner text and the index after it.
(String, int)? _group(String s, int i) {
  if (i >= s.length || s[i] != '{') return null;
  var depth = 0;
  for (var j = i; j < s.length; j++) {
    if (s[j] == '{') depth++;
    if (s[j] == '}' && --depth == 0) return (s.substring(i + 1, j), j + 1);
  }
  return null;
}

String _script(String s, Map<String, String> table, String marker) {
  final sb = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final m = table[ch];
    if (m == null) return s.length == 1 ? '$marker$s' : '$marker($s)';
    sb.write(m);
  }
  return sb.toString();
}

String _math(String input) {
  var s = input;
  // Commands that take arguments: rewrite from the inside out until nothing changes.
  for (var pass = 0; pass < 8; pass++) {
    final before = s;
    final out = StringBuffer();
    var i = 0;
    while (i < s.length) {
      if (s[i] != '\\') {
        out.write(s[i++]);
        continue;
      }
      final m = RegExp(r'\\([A-Za-z]+)\*?').matchAsPrefix(s, i);
      if (m == null) {
        // \, \; \: \! \  \\ \{ \} \% \& \_ \# \| and friends.
        final next = i + 1 < s.length ? s[i + 1] : '';
        out.write(switch (next) {
          ',' || ';' || ':' || ' ' || '\\' => ' ',
          '!' => '',
          '|' => '‖',
          '' => '',
          _ => next,
        });
        i += 2;
        continue;
      }
      final name = m.group(1)!;
      var j = m.end;
      while (j < s.length && s[j] == ' ' && (name == 'frac' || name == 'sqrt' || _wrappers.contains(name) || _accents.containsKey(name) || name == 'mathbb')) {
        j++;
      }
      if (name == 'frac' || name == 'dfrac' || name == 'tfrac') {
        final a = _group(s, j);
        final b = a == null ? null : _group(s, a.$2);
        if (a != null && b != null) {
          String wrap(String t) => RegExp(r'^[\w.]+$').hasMatch(t) ? t : '($t)';
          out.write('${wrap(_math(a.$1))}/${wrap(_math(b.$1))}');
          i = b.$2;
          continue;
        }
      } else if (name == 'sqrt') {
        var k = j;
        if (k < s.length && s[k] == '[') {
          final close = s.indexOf(']', k);
          if (close > 0) k = close + 1;
        }
        final a = _group(s, k);
        if (a != null) {
          final inner = _math(a.$1);
          out.write(inner.length == 1 ? '√$inner' : '√($inner)');
          i = a.$2;
          continue;
        }
      } else if (name == 'mathbb' || name == 'Bbb') {
        final a = _group(s, j);
        final t = a != null ? _math(a.$1) : (j < s.length ? s[j] : '');
        out.write(t.length == 1 ? (_blackboard[t] ?? t) : t);
        i = a != null ? a.$2 : j + 1;
        continue;
      } else if (_wrappers.contains(name)) {
        final a = _group(s, j);
        if (a != null) {
          out.write(_math(a.$1));
          i = a.$2;
          continue;
        }
        i = j; // "\rm x": drop the switch, keep the text
        continue;
      } else if (_accents.containsKey(name)) {
        final a = _group(s, j);
        final t = a != null ? _math(a.$1) : (j < s.length ? s[j] : '');
        out.write(t.isEmpty ? '' : '${t.length == 1 ? t : '($t)'}${_accents[name]}');
        i = a != null ? a.$2 : j + 1;
        continue;
      } else if (_greek.containsKey(name)) {
        out.write(_greek[name]);
      } else if (_symbols.containsKey(name)) {
        out.write(_symbols[name]);
      } else if (_functions.contains(name)) {
        out.write(name);
      } else if (name == 'left' || name == 'right' || name == 'big' || name == 'Big' || name == 'bigg' || name == 'Bigg' || name == 'limits' ||
          name == 'nolimits' || name == 'quad' || name == 'qquad' || name == 'ensuremath' || name == 'displaystyle') {
        if (name == 'quad' || name == 'qquad') out.write(' ');
        if (j < s.length && s[j] == '.') j++; // "\right." has no visible delimiter
      } else {
        out.write(name); // unknown command: keep its name rather than show a backslash
      }
      i = j;
    }
    s = out.toString();
    if (s == before) break;
  }
  // Superscripts and subscripts, now that the arguments are plain.
  s = s.replaceAllMapped(RegExp(r'\^\s*(?:\{([^{}]*)\}|([A-Za-z0-9+\-−*′]))'), (m) => _script((m.group(1) ?? m.group(2))!.trim(), _sup, '^'));
  s = s.replaceAllMapped(RegExp(r'_\s*(?:\{([^{}]*)\}|([A-Za-z0-9+\-−]))'), (m) => _script((m.group(1) ?? m.group(2))!.trim(), _sub, '_'));
  return s.replaceAll(RegExp(r'[{}]'), '').replaceAll('~', ' ').replaceAll(RegExp(r'[ \t]+'), ' ').trim();
}

final _mathSpan = RegExp(r'\$\$([\s\S]+?)\$\$|\$([^$\n]{1,300}?)\$|\\\(([\s\S]+?)\\\)|\\\[([\s\S]+?)\\\]');

const _entities = {'&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'", '&apos;': "'", '&nbsp;': ' ', '&ndash;': '–', '&mdash;': '—'};

/// Plain readable text from an abstract or title. Safe to call on text that has no markup.
String tidyText(String? input) {
  var s = input ?? '';
  if (s.isEmpty) return s;
  if (s.contains('<')) s = s.replaceAll(RegExp(r'</?[A-Za-z][^>]*>'), ' ');
  if (s.contains('&')) {
    _entities.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)));
    s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)));
  }
  if (s.contains(r'$') || s.contains(r'\')) {
    s = s.replaceAllMapped(_mathSpan, (m) {
      final inner = m.group(1) ?? m.group(2) ?? m.group(3) ?? m.group(4) ?? '';
      // "costs $5 and $10" is money, not maths: real maths does not start or end with a space.
      if (m.group(2) != null && (inner.startsWith(' ') || inner.endsWith(' ') || RegExp(r'^[\d.,]+$').hasMatch(inner))) return m.group(0)!;
      return _math(inner);
    });
    if (s.contains(r'\')) s = _math(s);
  }
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
