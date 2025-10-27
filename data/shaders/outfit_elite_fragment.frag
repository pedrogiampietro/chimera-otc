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
        // Subtle green aura with gentle pulsing
        float pulse = sin(u_Time * 2.0) * 0.2 + 0.8;
        vec4 greenAura = vec4(0.3, 0.8, 0.4, pulse * 0.4);
        
        // Apply gentle green tint
        gl_FragColor = mix(gl_FragColor, gl_FragColor * greenAura, 0.3);
        gl_FragColor *= effectColor;
        
        // Add subtle glow
        gl_FragColor.rgb += greenAura.rgb * 0.1 * pulse;
    }
    if(gl_FragColor.a < 0.01) discard;
}
