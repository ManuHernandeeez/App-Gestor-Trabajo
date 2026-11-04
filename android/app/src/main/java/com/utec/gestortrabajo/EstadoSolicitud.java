package com.utec.gestortrabajo;

import android.content.Context;
import android.graphics.drawable.GradientDrawable;
import android.widget.TextView;

// Texto y colores de cada estado de una solicitud.
public class EstadoSolicitud {

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
            case "publicada":
                return contexto.getString(R.string.estado_publicada);
            case "asignada":
                return contexto.getString(R.string.estado_asignada);
            case "en_proceso":
                return contexto.getString(R.string.estado_en_proceso);
            case "finalizada":
                return contexto.getString(R.string.estado_finalizada);
            case "cancelada":
                return contexto.getString(R.string.estado_cancelada);
            case "vencida":
                return contexto.getString(R.string.estado_vencida);
            default:
                return estado;
        }
    }

    // publicada ámbar, asignada y en proceso azul, finalizada verde, cancelada y vencida gris
    private static int colorFondo(String estado) {
        switch (estado) {
            case "publicada":
                return R.color.aviso_fondo;
            case "asignada":
            case "en_proceso":
                return R.color.info_fondo;
            case "finalizada":
                return R.color.exito_fondo;
            default:
                return R.color.neutro_fondo;
        }
    }

    private static int colorTexto(String estado) {
        switch (estado) {
            case "publicada":
                return R.color.aviso_texto;
            case "asignada":
            case "en_proceso":
                return R.color.info_texto;
            case "finalizada":
                return R.color.exito_texto;
            default:
                return R.color.neutro_texto;
        }
    }
}
