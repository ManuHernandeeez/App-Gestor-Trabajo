package com.utec.gestortrabajo;

import android.app.Activity;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Patterns;
import android.view.View;
import android.widget.EditText;

import com.google.android.material.textfield.TextInputLayout;

// Reglas de los campos de los formularios y aviso de error en el momento justo:
// al salir del campo, no mientras se escribe. Una vez mostrado, se quita en cuanto el valor queda bien.
public class Validacion {

    // Devuelve el texto del error, o 0 si el valor es válido
    public interface Regla {
        int error(String texto);
    }

    public static final Regla CORREO = new Regla() {
        @Override
        public int error(String texto) {
            return Patterns.EMAIL_ADDRESS.matcher(texto.trim()).matches() ? 0 : R.string.correo_invalido;
        }
    };

    // La contraseña no se recorta: un espacio al final es parte de la clave
    public static final Regla CLAVE = new Regla() {
        @Override
        public int error(String texto) {
            return texto.length() >= 8 && texto.length() <= 72 ? 0 : R.string.clave_invalida;
        }
    };

    public static final Regla TELEFONO = new Regla() {
        @Override
        public int error(String texto) {
            return texto.trim().matches("\\d{4}-\\d{4}") ? 0 : R.string.telefono_invalido;
        }
    };

    public static final Regla DUI = new Regla() {
        @Override
        public int error(String texto) {
            return texto.trim().matches("\\d{8}-\\d") ? 0 : R.string.dui_formato;
        }
    };

    // idCapa es el TextInputLayout del campo. Un campo vacío no se marca: eso lo avisa el botón al enviar.
    public static void alSalir(Activity pantalla, int idCapa, final Regla regla) {
        final TextInputLayout capa = pantalla.findViewById(idCapa);
        EditText campo = capa.getEditText();
        campo.setOnFocusChangeListener(new View.OnFocusChangeListener() {
            @Override
            public void onFocusChange(View vista, boolean tieneFoco) {
                if (!tieneFoco) {
                    revisar(capa, regla);
                }
            }
        });
        campo.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence texto, int inicio, int cantidad, int despues) {
            }

            @Override
            public void onTextChanged(CharSequence texto, int inicio, int antes, int cantidad) {
            }

            @Override
            public void afterTextChanged(Editable texto) {
                if (capa.getError() != null) {
                    revisar(capa, regla);
                }
            }
        });
    }

    private static void revisar(TextInputLayout capa, Regla regla) {
        String texto = capa.getEditText().getText().toString();
        int error = texto.isEmpty() ? 0 : regla.error(texto);
        capa.setError(error == 0 ? null : capa.getContext().getString(error));
    }
}
