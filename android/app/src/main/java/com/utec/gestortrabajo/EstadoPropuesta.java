package com.utec.gestortrabajo;

import android.content.Context;
import android.graphics.drawable.GradientDrawable;
import android.widget.TextView;

// Texto y colores de cada estado de una propuesta.
public class EstadoPropuesta {

    // Pone el texto y los colores en una etiqueta con fondo fondo_etiqueta
    public static void pintar(TextView etiqueta, String estado) {
        Context contexto = etiqueta.getContext();
        etiqueta.setText(texto(contexto, estado));
        etiqueta.setTextColor(contexto.getColor(colorTexto(estado)));
        GradientDrawable fondo = (GradientDrawable) etiqueta.getBackground().mutate();
        fondo.setColor(contexto.getColor(colorFondo(estado)));
    }

    public static String texto(Context contexto, String estado) {
        switch (estado) {
            case "pendiente":
                return contexto.getString(R.string.estado_pendiente);
            case "aceptada":
                return contexto.getString(R.string.estado_aceptada);
            case "rechazada":
                return contexto.getString(R.string.estado_rechazada);
            case "retirada":
                return contexto.getString(R.string.estado_retirada);
            default:
                return estado;
        }
    }

    // pendiente ámbar, aceptada verde, rechazada y retirada gris: rechazar es informativo, no una alarma
    private static int colorFondo(String estado) {
        switch (estado) {
            case "pendiente":
                return R.color.aviso_fondo;
            case "aceptada":
                return R.color.exito_fondo;
            default:
                return R.color.neutro_fondo;
        }
    }

    private static int colorTexto(String estado) {
        switch (estado) {
            case "pendiente":
                return R.color.aviso_texto;
            case "aceptada":
                return R.color.exito_texto;
            default:
                return R.color.neutro_texto;
        }
    }
}
