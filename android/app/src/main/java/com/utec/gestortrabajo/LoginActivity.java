package com.utec.gestortrabajo;

import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONException;
import org.json.JSONObject;

public class LoginActivity extends AppCompatActivity {

    private EditText edtCorreo;
    private EditText edtClave;
    private Button btnEntrar;
    private Sesion sesion;
    private boolean ocupado = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        sesion = new Sesion(this);
        if (sesion.estaAbierta() && abrirMenu(sesion.obtenerRol())) {
            finish();
            return;
        }

        setContentView(R.layout.activity_login);
        Ventana.preparar(this, findViewById(R.id.raiz));
        edtCorreo = findViewById(R.id.edtCorreo);
        edtClave = findViewById(R.id.edtClave);
        btnEntrar = findViewById(R.id.btnEntrar);
        Atras.protegerSiempre(this, Atras.salirDeLaApp());

        // la tecla Listo del teclado entra, como el botón
        edtClave.setOnEditorActionListener(new TextView.OnEditorActionListener() {
            @Override
            public boolean onEditorAction(TextView campo, int accion, KeyEvent evento) {
                if (accion == EditorInfo.IME_ACTION_DONE) {
                    entrar(campo);
                    return true;
                }
                return false;
            }
        });

        // las cuentas de demostración solo salen en la versión de depuración, nunca en una instalada por los usuarios
        boolean depuracion = (getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
        findViewById(R.id.vistaPruebas).setVisibility(Config.ACCESO_DE_PRUEBA && depuracion ? View.VISIBLE : View.GONE);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }

    // Botón Entrar
    public void entrar(View vista) {
        String correo = edtCorreo.getText().toString().trim();
        String clave = edtClave.getText().toString();
        if (correo.isEmpty() || clave.isEmpty()) {
            Toast.makeText(this, R.string.falta_datos, Toast.LENGTH_SHORT).show();
            return;
        }
        iniciarSesion(correo, clave);
    }

    // Enlace Crear cuenta. Al registrarse, RegistroActivity se cierra y se vuelve aquí.
    public void crearCuenta(View vista) {
        startActivity(new Intent(this, RegistroActivity.class));
    }

    // Título de las cuentas de demostración: pliega o despliega los botones
    public void alternarPruebas(View titulo) {
        View cuentas = findViewById(R.id.vistaCuentasPrueba);
        boolean abrir = cuentas.getVisibility() != View.VISIBLE;
        cuentas.setVisibility(abrir ? View.VISIBLE : View.GONE);
        ((TextView) titulo).setCompoundDrawablesRelativeWithIntrinsicBounds(0, 0,
                abrir ? R.drawable.ic_flecha_arriba : R.drawable.ic_flecha_abajo, 0);
    }

    // Botones del acceso de prueba: el correo de la cuenta de ejemplo viene en el tag del botón
    public void entrarDePrueba(View vista) {
        iniciarSesion((String) vista.getTag(), Config.CLAVE_DE_PRUEBA);
    }

    private void iniciarSesion(String correo, String clave) {
        if (ocupado) {
            return;
        }
        JSONObject cuerpo = new JSONObject();
        try {
            cuerpo.put("correo", correo);
            cuerpo.put("password", clave);
        } catch (JSONException e) {
            return;
        }

        ocupado = true;
        Ventana.ocupar(btnEntrar, R.string.entrando);
        ClienteApi.pedir(this, "POST", "api/auth/login", cuerpo.toString(), new ClienteApi.Respuesta() {
            @Override
            public void alExito(String respuesta) {
                ocupado = false;
                Ventana.liberar(btnEntrar, R.string.boton_entrar);
                recibirSesion(respuesta);
            }

            @Override
            public void alError(int codigo, String mensaje) {
                ocupado = false;
                Ventana.liberar(btnEntrar, R.string.boton_entrar);
            }
        });
    }

    private void recibirSesion(String respuesta) {
        try {
            JSONObject json = new JSONObject(respuesta);
            sesion.guardar(json.getString("token"), json.getString("rol"), json.getInt("usuarioId"), json.getString("nombre"));
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        if (abrirMenu(sesion.obtenerRol())) {
            finish();
        }
    }

    // Cliente va a sus solicitudes, trabajador a los trabajos de su zona y administrador a los catálogos.
    // Devuelve false si no hay pantalla para el rol.
    // Cliente y trabajador reciben el extra "sincronizar" para pedir los mensajes y avisos nuevos al abrir la app.
    private boolean abrirMenu(String rol) {
        Intent intent;
        if (rol.equals("cliente")) {
            intent = new Intent(this, MisSolicitudesActivity.class);
            intent.putExtra("sincronizar", true);
        } else if (rol.equals("trabajador")) {
            intent = new Intent(this, TrabajosZonaActivity.class);
            intent.putExtra("sincronizar", true);
        } else if (rol.equals("administrador")) {
            intent = new Intent(this, AdminCatalogosActivity.class);
        } else {
            return false;
        }
        startActivity(intent);
        return true;
    }
}
