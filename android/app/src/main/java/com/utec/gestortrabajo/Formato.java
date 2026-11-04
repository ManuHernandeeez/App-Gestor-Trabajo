package com.utec.gestortrabajo;

import android.content.Context;

import java.text.Normalizer;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

// Textos que se repiten en varias pantallas.
public class Formato {

    // 40 se muestra como $40.00
    public static String dinero(double valor) {
        return String.format(Locale.US, "$%.2f", valor);
    }

    // Lee un monto escrito por la persona: acepta coma o punto decimal. Devuelve 0 si no es un número.
    public static double numero(String texto) {
        try {
            return Double.parseDouble(texto.trim().replace(',', '.'));
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    public static String propuestas(Context contexto, int cantidad) {
        if (cantidad == 0) {
            return contexto.getString(R.string.propuestas_ninguna);
        }
        if (cantidad == 1) {
            return contexto.getString(R.string.propuestas_una);
        }
        return contexto.getString(R.string.propuestas_varias, cantidad);
    }

    // Promedio de estrellas con un decimal y la cantidad, por ejemplo "4.5 (6)"
    public static String calificacion(Context contexto, double promedio, int total) {
        if (total == 0) {
            return contexto.getString(R.string.sin_calificaciones);
        }
        return String.format(Locale.US, "%.1f (%d)", promedio, total);
    }

    // "Escalón" queda como "escalon", para buscar sin importar tildes ni mayúsculas
    public static String sinTildes(String texto) {
        String separado = Normalizer.normalize(texto, Normalizer.Form.NFD);
        return separado.replaceAll("\\p{M}", "").toLowerCase(Locale.ROOT);
    }

    // Fecha ISO 8601 de la API en hora local: "15:30" si es de hoy y "03/11 15:30" si no
    public static String fechaHora(String iso) {
        ZonedDateTime fecha = OffsetDateTime.parse(iso).atZoneSameInstant(ZoneId.systemDefault());
        String patron = fecha.toLocalDate().equals(LocalDate.now()) ? "HH:mm" : "dd/MM HH:mm";
        return fecha.format(DateTimeFormatter.ofPattern(patron, Locale.US));
    }

    public static String hace(Context contexto, int horas) {
        if (horas < 1) {
            return contexto.getString(R.string.hace_menos_hora);
        }
        if (horas < 24) {
            return contexto.getString(R.string.hace_horas, horas);
        }
        int dias = horas / 24;
        if (dias == 1) {
            return contexto.getString(R.string.hace_un_dia);
        }
        return contexto.getString(R.string.hace_dias, dias);
    }
}
