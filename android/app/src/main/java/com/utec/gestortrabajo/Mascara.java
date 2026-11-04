package com.utec.gestortrabajo;

import android.text.Editable;
import android.text.TextWatcher;
import android.view.View;
import android.widget.EditText;

import java.util.Locale;

// Formato automático de los campos: la persona escribe solo dígitos y la app pone el guion.
// El texto del campo queda tal cual lo espera la API: 0000-0000 en el teléfono y 00000000-0 en el DUI.
public class Mascara {

    // Teléfono: el guion sale al escribir el quinto dígito. Si se pega con el prefijo +503, se quita.
    public static void telefono(EditText campo) {
        poner(campo, "503", 4, 8);
    }

    // DUI: el guion sale al escribir el noveno dígito
    public static void dui(EditText campo) {
        poner(campo, "", 8, 9);
    }

    // Monto: al salir del campo queda con dos decimales, por ejemplo 40 pasa a 40.00
    public static void dinero(final EditText campo) {
        campo.setOnFocusChangeListener(new View.OnFocusChangeListener() {
            @Override
            public void onFocusChange(View vista, boolean tieneFoco) {
                double valor = Formato.numero(campo.getText().toString());
                if (!tieneFoco && valor > 0) {
                    campo.setText(String.format(Locale.US, "%.2f", valor));
                }
            }
        });
    }

    private static void poner(EditText campo, final String prefijoPais, final int antesDelGuion, final int totalDigitos) {
        campo.addTextChangedListener(new TextWatcher() {
            private boolean cambiando = false;

            @Override
            public void beforeTextChanged(CharSequence texto, int inicio, int cantidad, int despues) {
            }

            @Override
            public void onTextChanged(CharSequence texto, int inicio, int antes, int cantidad) {
            }

            @Override
            public void afterTextChanged(Editable texto) {
                if (cambiando) {
                    return;
                }
                String formateado = formatear(texto.toString(), prefijoPais, antesDelGuion, totalDigitos);
                if (!formateado.equals(texto.toString())) {
                    cambiando = true;
                    texto.replace(0, texto.length(), formateado);
                    cambiando = false;
                }
            }
        });
    }

    // Deja solo los dígitos, quita el prefijo del país si venía pegado y pone el guion
    private static String formatear(String texto, String prefijoPais, int antesDelGuion, int totalDigitos) {
        String digitos = texto.replaceAll("\\D", "");
        if (!prefijoPais.isEmpty() && digitos.length() > totalDigitos && digitos.startsWith(prefijoPais)) {
            digitos = digitos.substring(prefijoPais.length());
        }
        if (digitos.length() > totalDigitos) {
            digitos = digitos.substring(0, totalDigitos);
        }
        if (digitos.length() <= antesDelGuion) {
            return digitos;
        }
        return digitos.substring(0, antesDelGuion) + "-" + digitos.substring(antesDelGuion);
    }
}
