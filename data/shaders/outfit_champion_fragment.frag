uniform mat4 u_Color;
varying vec2 v_TexCoord;
varying vec2 v_TexCoord2;
varying vec2 v_TexCoord3;
uniform sampler2D u_Tex0;
uniform sampler2D u_Tex1;
uniform float u_Time;

void main()
{
    gl_FragColor = texture2D(u_Tex0, v_TexCoord);
    vec4 texcolor = texture2D(u_Tex0, v_TexCoord2);
    vec4 effectColor = texture2D(u_Tex1, v_TexCoord3);
    
    if(texcolor.a > 0.1) {
        // Elegant red aura with gentle flickering
        float flicker = sin(u_Time * 3.0) * 0.15 + 0.85;
        vec4 redAura = vec4(0.8, 0.2, 0.2, flicker * 0.5);
        
        // Apply elegant red tint
        gl_FragColor = mix(gl_FragColor, gl_FragColor * redAura, 0.4);
        gl_FragColor *= effectColor;
        
        // Add subtle red glow
        gl_FragColor.rgb += redAura.rgb * 0.15 * flicker;
    }
    if(gl_FragColor.a < 0.01) discard;
}
