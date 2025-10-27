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
        // Refined golden aura with elegant pulsing
        float pulse = sin(u_Time * 1.5) * 0.25 + 0.75;
        float shimmer = sin(u_Time * 4.0) * 0.1 + 0.9;
        
        // Golden aura
        vec4 goldenAura = vec4(1.0, 0.8, 0.3, pulse * 0.6);
        
        // Purple accent
        vec4 purpleAccent = vec4(0.7, 0.3, 0.9, shimmer * 0.3);
        
        // Apply refined golden tint
        gl_FragColor = mix(gl_FragColor, gl_FragColor * goldenAura, 0.5);
        gl_FragColor *= effectColor;
        
        // Add purple accent
        gl_FragColor.rgb += purpleAccent.rgb * 0.1 * shimmer;
        
        // Add elegant golden glow
        gl_FragColor.rgb += goldenAura.rgb * 0.2 * pulse;
    }
    if(gl_FragColor.a < 0.01) discard;
}
