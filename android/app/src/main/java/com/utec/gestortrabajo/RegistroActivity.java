package com.utec.gestortrabajo;

import android.os.Bundle;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.button.MaterialButtonToggleGroup;
import com.google.android.material.chip.ChipGroup;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;

// Pantalla sin sesión: crear una cuenta de cliente o de trabajador. El cliente elige la colonia donde vive; el
// trabajador escribe su DUI (lo valida el servidor) y elige sus oficios y las colonias donde trabaja.
// Al terminar vuelve al login.
public class RegistroActivity extends AppCompatActivity {

    private MaterialButtonToggleGroup vistaRol;
    private EditText edtNombre;
    private EditText edtCorreo;
    private EditText edtClave;
    private EditText edtTelefono;
    private EditText edtDui;
    private View vistaDui;
    private TextView txtZona;
    private View vistaTrabajo;
    private ChipGroup vistaOficios;
    private Button btnRegistrar;
    private SelectorZona zona;
    private boolean registrando = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_registro);
        Ventana.preparar(this, findViewById(R.id.raiz));

        vistaRol = findViewById(R.id.vistaRol);
        edtNombre = findViewById(R.id.edtNombre);
        edtCorreo = findViewById(R.id.edtCorreo);
        edtClave = findViewById(R.id.edtClave);
        edtTelefono = findViewById(R.id.edtTelefono);
        edtDui = findViewById(R.id.edtDui);
        vistaDui = findViewById(R.id.vistaDui);
        txtZona = findViewById(R.id.txtZona);
        vistaTrabajo = findViewById(R.id.vistaTrabajo);
        vistaOficios = findViewById(R.id.vistaOficios);
        btnRegistrar = findViewById(R.id.btnRegistrar);
        zona = new SelectorZona(this);

        // el guion de teléfono y DUI lo pone la app; los errores salen al dejar cada campo
        Mascara.telefono(edtTelefono);
        Mascara.dui(edtDui);
        Validacion.alSalir(this, R.id.capaCorreo, Validacion.CORREO);
        Validacion.alSalir(this, R.id.capaClave, Validacion.CLAVE);
        Validacion.alSalir(this, R.id.capaTelefono, Validacion.TELEFONO);
        Validacion.alSalir(this, R.id.vistaDui, Validacion.DUI);

        // si ya hay algo escrito, Atrás pregunta antes de perderlo
        Atras.proteger(this, new Atras.Regla() {
            @Override
            public Atras.Pregunta preguntar() {
                if (!hayDatos()) {
                    return null;
                }
                return Atras.descartar(R.string.cancelar_registro_titulo, R.string.cancelar_registro_mensaje);
            }
        });

        vistaRol.addOnButtonCheckedListener(new MaterialButtonToggleGroup.OnButtonCheckedListener() {
            @Override
            public void onButtonChecked(MaterialButtonToggleGroup grupo, int idBoton, boolean marcado) {
                mostrarSegunRol();
            }
        });

        mostrarSegunRol();
        CasillasOficios.cargar(this, vistaOficios, new ArrayList<Integer>());
        zona.cargar();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }

    // Flecha de volver: hace lo mismo que el botón Atrás del teléfono, incluido el aviso
    public void volver(View vista) {
        getOnBackPressedDispatcher().onBackPressed();
    }

    // Algo escrito o elegido que se perdería al salir. Cambiar entre Cliente y Trabajador no cuenta.
    private boolean hayDatos() {
        return escrito(edtNombre) || escrito(edtCorreo) || escrito(edtTelefono) || escrito(edtDui)
                || !edtClave.getText().toString().isEmpty()
                || zona.municipioId() != 0
                || !CasillasOficios.marcados(vistaOficios).isEmpty();
    }

    private boolean escrito(EditText campo) {
        return !campo.getText().toString().trim().isEmpty();
    }

    private boolean esTrabajador() {
        return vistaRol.getCheckedButtonId() == R.id.btnRolTrabajador;
    }

    // El DUI, los oficios y varias colonias son del trabajador; el cliente elige solo la colonia donde vive
    private void mostrarSegunRol() {
        boolean trabajador = esTrabajador();
        vistaDui.setVisibility(trabajador ? View.VISIBLE : View.GONE);
        vistaTrabajo.setVisibility(trabajador ? View.VISIBLE : View.GONE);
        txtZona.setText(trabajador ? R.string.etiqueta_zona_trabajo : R.string.etiqueta_zona_cliente);
        // la tecla del teléfono dice Siguiente si falta el DUI y Listo si es el último campo de texto
        edtTelefono.setImeOptions(trabajador ? EditorInfo.IME_ACTION_NEXT : EditorInfo.IME_ACTION_DONE);
        zona.elegirVarias(trabajador);
    }

    // Botón Crear cuenta
    public void registrar(View vista) {
        if (registrando) {
            return;
        }
        String nombre = edtNombre.getText().toString().trim();
        String correo = edtCorreo.getText().toString().trim();
        String clave = edtClave.getText().toString();
        String telefono = edtTelefono.getText().toString().trim();
        String dui = edtDui.getText().toString().trim();
        int falta = validar(nombre, correo, clave, telefono, dui);
        if (falta != 0) {
            Toast.makeText(this, falta, Toast.LENGTH_SHORT).show();
            return;
        }

        JSONObject cuerpo = new JSONObject();
        try {
            cuerpo.put("rol", esTrabajador() ? "trabajador" : "cliente");
            cuerpo.put("nombre", nombre);
            cuerpo.put("correo", correo);
            cuerpo.put("password", clave);
            cuerpo.put("telefono", telefono);
            cuerpo.put("municipioId", zona.municipioId());
            if (esTrabajador()) {
                cuerpo.put("dui", dui);
                cuerpo.put("oficios", new JSONArray(CasillasOficios.marcados(vistaOficios)));
                cuerpo.put("colonias", new JSONArray(zona.coloniaIds()));
            } else {
                cuerpo.put("coloniaId", zona.coloniaId());
            }
        } catch (JSONException e) {
            return;
        }

        registrando = true;
        Ventana.ocupar(btnRegistrar, R.string.creando_cuenta);
        ClienteApi.pedir(this, "POST", "api/auth/registro", cuerpo.toString(), new ClienteApi.Respuesta() {
            @Override
            public void alExito(String respuesta) {
                Toast.makeText(RegistroActivity.this, R.string.cuenta_creada, Toast.LENGTH_LONG).show();
                finish();
            }

            @Override
            public void alError(int codigo, String mensaje) {
                registrando = false;
                Ventana.liberar(btnRegistrar, R.string.boton_registrar);
            }
        });
    }

    // Devuelve el texto a mostrar si falta algo, o 0 si está completo. La validación completa (DUI incluido)
    // la hace el servidor y su mensaje sale en el Toast de ClienteApi.
    private int validar(String nombre, String correo, String clave, String telefono, String dui) {
        if (nombre.isEmpty()) {
            return R.string.falta_nombre;
        }
        int error = Validacion.CORREO.error(correo);
        if (error == 0) {
            error = Validacion.CLAVE.error(clave);
        }
        if (error == 0) {
            error = Validacion.TELEFONO.error(telefono);
        }
        if (error == 0 && esTrabajador()) {
            error = Validacion.DUI.error(dui);
        }
        if (error != 0) {
            return error;
        }
        if (zona.municipioId() == 0) {
            return R.string.falta_municipio;
        }
        if (!esTrabajador()) {
            return zona.coloniaId() == 0 ? R.string.falta_colonia : 0;
        }
        if (zona.coloniaIds().isEmpty()) {
            return R.string.falta_colonias_trabajo;
        }
        if (CasillasOficios.marcados(vistaOficios).isEmpty()) {
            return R.string.falta_oficio;
        }
        return 0;
    }
}
