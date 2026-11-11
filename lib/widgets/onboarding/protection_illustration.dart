import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Minimalist line-art illustration of an Indian woman with folded hands (Namaste)
/// matching the exact reference style and using the button accent coral (#E8836B).
///
/// Features clean vector lines, hair tied in a bun, bindi, jhumka earrings,
/// bangles on wrists, and hands pressed in Anjali Mudra.
class ProtectionIllustration extends StatelessWidget {
  const ProtectionIllustration({super.key, this.size = 130});

  final double size;

  static const String _minimalistNamasteSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 240" width="100%" height="100%">
  <defs>
    <radialGradient id="subtleGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#E8836B" stop-opacity="0.18" />
      <stop offset="70%" stop-color="#E8836B" stop-opacity="0.04" />
      <stop offset="100%" stop-color="#1A0A14" stop-opacity="0" />
    </radialGradient>
  </defs>

  <!-- Ambient Glow -->
  <circle cx="120" cy="120" r="114" fill="url(#subtleGlow)" />

  <!-- Outer Accent Circle Frame -->
  <circle cx="120" cy="120" r="104" fill="#24101B" stroke="#E8836B" stroke-width="1.8" opacity="0.85" />
  <circle cx="120" cy="120" r="109" fill="none" stroke="#E8836B" stroke-width="0.8" stroke-dasharray="3 4" opacity="0.4" />

  <!-- Woman in Namaste line art in accent color #E8836B -->
  <g stroke="#E8836B" stroke-linecap="round" stroke-linejoin="round" fill="none">

    <!-- Hair Bun at Back -->
    <ellipse cx="120" cy="40" rx="26" ry="22" fill="#E8836B" stroke="#E8836B" stroke-width="2" />

    <!-- Head Outline / Hair Back -->
    <path d="M 85 86 C 82 58, 100 42, 120 42 C 140 42, 158 58, 155 86 C 152 108, 138 120, 120 120 C 102 120, 88 108, 85 86 Z" fill="#2A121F" stroke="#E8836B" stroke-width="2" />

    <!-- Hair Front Waves & Middle Parting -->
    <path d="M 120 54 Q 102 62, 88 80" stroke-width="2.2" />
    <path d="M 120 54 Q 138 62, 152 80" stroke-width="2.2" />

    <!-- Left & Right Ears -->
    <path d="M 88 80 C 82 82, 82 94, 88 98" stroke-width="1.6" />
    <path d="M 152 80 C 158 82, 158 94, 152 98" stroke-width="1.6" />

    <!-- Traditional Earrings / Jhumkas -->
    <circle cx="83" cy="98" r="2.5" fill="#E8836B" />
    <path d="M 80 103 C 80 101, 86 101, 86 103 C 86 108, 80 108, 80 103 Z" stroke-width="1.4" fill="#E8836B" />
    <circle cx="157" cy="98" r="2.5" fill="#E8836B" />
    <path d="M 154 103 C 154 101, 160 101, 160 103 C 160 108, 154 108, 154 103 Z" stroke-width="1.4" fill="#E8836B" />

    <!-- Face Silhouette / Chin -->
    <path d="M 94 80 C 94 98, 104 116, 120 116 C 136 116, 146 98, 146 80" stroke-width="1.8" />

    <!-- Bindi (Solid Coral Dot) -->
    <circle cx="120" cy="74" r="3.2" fill="#E8836B" stroke="none" />

    <!-- Eyebrows (Arched, graceful) -->
    <path d="M 99 80 Q 108 74 115 78" stroke-width="2" />
    <path d="M 141 80 Q 132 74 125 78" stroke-width="2" />

    <!-- Serene Closed Eyes (Peaceful crescent with subtle lash) -->
    <path d="M 101 87 Q 108 92 115 87" stroke-width="2" />
    <path d="M 139 87 Q 132 92 125 87" stroke-width="2" />
    <line x1="108" y1="90" x2="108" y2="92.5" stroke-width="1.4" />
    <line x1="132" y1="90" x2="132" y2="92.5" stroke-width="1.4" />

    <!-- Nose (Delicate profile) -->
    <path d="M 120 85 L 120 97 Q 123 99 120 100" stroke-width="1.4" />

    <!-- Gentle Serene Smile -->
    <path d="M 114 105 Q 117 103.5 120 105 Q 123 103.5 126 105" stroke-width="1.4" />
    <path d="M 115 107.5 Q 120 111 125 107.5" stroke-width="1.4" />

    <!-- Neck Lines -->
    <path d="M 110 115 L 110 126" stroke-width="1.6" />
    <path d="M 130 115 L 130 126" stroke-width="1.6" />

    <!-- Collar / Neckline -->
    <path d="M 98 132 Q 120 144 142 132" stroke-width="1.8" />

    <!-- Shoulders & Upper Body -->
    <path d="M 98 132 C 78 135, 52 148, 34 188" stroke-width="2" />
    <path d="M 142 132 C 162 135, 188 148, 206 188" stroke-width="2" />

    <!-- Forearms curving inwards towards center -->
    <path d="M 34 188 C 50 206, 75 204, 94 185" stroke-width="2" />
    <path d="M 206 188 C 190 206, 165 204, 146 185" stroke-width="2" />

    <!-- Inner Arm Lines to Wrists -->
    <path d="M 68 180 C 82 176, 94 170, 102 165" stroke-width="1.6" />
    <path d="M 172 180 C 158 176, 146 170, 138 165" stroke-width="1.6" />

    <!-- Traditional Bangles (3 on each wrist) -->
    <ellipse cx="96" cy="180" rx="5.5" ry="12" fill="#E8836B" stroke="#24101B" stroke-width="1" transform="rotate(-30 96 180)" />
    <ellipse cx="91" cy="183" rx="5.5" ry="12" fill="#E8836B" stroke="#24101B" stroke-width="1" transform="rotate(-30 91 183)" />
    <ellipse cx="86" cy="186" rx="5.5" ry="12" fill="#E8836B" stroke="#24101B" stroke-width="1" transform="rotate(-30 86 186)" />

    <ellipse cx="144" cy="180" rx="5.5" ry="12" fill="#E8836B" stroke="#24101B" stroke-width="1" transform="rotate(30 144 180)" />
    <ellipse cx="149" cy="183" rx="5.5" ry="12" fill="#E8836B" stroke="#24101B" stroke-width="1" transform="rotate(30 149 183)" />
    <ellipse cx="154" cy="186" rx="5.5" ry="12" fill="#E8836B" stroke="#24101B" stroke-width="1" transform="rotate(30 154 186)" />

    <!-- Folded Hands in Namaste (Anjali Mudra) -->
    <path d="M 104 176 C 103 162, 108 142, 120 120" stroke-width="2.2" />
    <path d="M 136 176 C 137 162, 132 142, 120 120" stroke-width="2.2" />
    <line x1="120" y1="120" x2="120" y2="175" stroke-width="1.8" />

    <!-- Thumbs resting gently near chest -->
    <path d="M 107 162 Q 114 167 120 167" stroke-width="1.8" />
    <path d="M 133 162 Q 126 167 120 167" stroke-width="1.8" />

    <!-- Finger crease details -->
    <path d="M 112 138 L 114 150" stroke-width="1.2" opacity="0.8" />
    <path d="M 128 138 L 126 150" stroke-width="1.2" opacity="0.8" />
    <path d="M 108 146 L 110 156" stroke-width="1.2" opacity="0.8" />
    <path d="M 132 146 L 130 156" stroke-width="1.2" opacity="0.8" />

  </g>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(
        _minimalistNamasteSvg,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
