package com.utec.gestortrabajo;

import android.content.ActivityNotFoundException;
import android.content.DialogInterface;
import android.content.Intent;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.chip.ChipGroup;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;

// Pantalla de cliente y trabajador: perfil propio. Foto, nombre, teléfono, zona y promedio de calificación.
// El trabajador además ve su DUI enmascarado (no se edita) y elige sus oficios y las colonias donde trabaja.
public class PerfilActivity extends AppCompatActivity {

    private static final int ELEGIR_FOTO = 1;

    private boolean esTrabajador;
    private TextView txtCargando;
    private View vistaPerfil;
    private ImageView imgFoto;
    private TextView txtCalificacion;
    private Button btnCambiarFoto;
    private EditText edtNombre;
    private EditText edtTelefono;
    private TextView txtDui;
    private ChipGroup vistaOficios;
    private Button btnGuardar;
    private SelectorZona zona;
    private boolean guardando = false;

    // Nombre y teléfono tal como están guardados en el servidor; null mientras el perfil no ha cargado
    private String nombreGuardado = null;
    private String telefonoGuardado = null;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_perfil);
        Ventana.preparar(this, findViewById(R.id.raiz));
        Barra.preparar(this, R.id.btnBarraPerfil);

        esTrabajador = new Sesion(this).obtenerRol().equals("trabajador");
        txtCargando = findViewById(R.id.txtCargando);
        vistaPerfil = findViewById(R.id.vistaPerfil);
        imgFoto = findViewById(R.id.imgFoto);
        txtCalificacion = findViewById(R.id.txtCalificacion);
        btnCambiarFoto = findViewById(R.id.btnCambiarFoto);
        edtNombre = findViewById(R.id.edtNombre);
        edtTelefono = findViewById(R.id.edtTelefono);
        txtDui = findViewById(R.id.txtDui);
        vistaOficios = findViewById(R.id.vistaOficios);
        btnGuardar = findViewById(R.id.btnGuardar);
        zona = new SelectorZona(this);
        Mascara.telefono(edtTelefono);
        Validacion.alSalir(this, R.id.capaTelefono, Validacion.TELEFONO);

        // Perfil es una pantalla principal: Atrás cierra la app. Si hay cambios sin guardar, el aviso lo dice.
        Atras.proteger(this, new Atras.Regla() {
            @Override
            public Atras.Pregunta preguntar() {
                if (hayCambios()) {
                    return new Atras.Pregunta(R.string.sin_guardar_titulo, R.string.sin_guardar_mensaje,
                            R.string.boton_salir, R.string.boton_seguir_editando);
                }
                return Atras.salirDeLaApp();
            }
        });

        imgFoto.setImageDrawable(getDrawable(R.drawable.foto_vacia));
        mostrarSegunRol();
        cargar();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }

    // Botón Actualizar: vuelve a pedir el perfil y descarta lo que no se guardó
    public void actualizar(View vista) {
        txtCargando.setText(R.string.cargando);
        cargar();
    }

    private void recordarGuardado() {
        nombreGuardado = edtNombre.getText().toString().trim();
        telefonoGuardado = edtTelefono.getText().toString().trim();
    }

    // Solo se miran nombre y teléfono; los oficios y la zona cargan aparte y no se comparan
    private boolean hayCambios() {
        return nombreGuardado != null
                && (!edtNombre.getText().toString().trim().equals(nombreGuardado)
                || !edtTelefono.getText().toString().trim().equals(telefonoGuardado));
    }

    // Botón Cerrar sesión: pide confirmar, por si se tocó en lugar de Guardar cambios
    public void cerrarSesion(View vista) {
        new MaterialAlertDialogBuilder(this)
                .setTitle(R.string.cerrar_sesion)
                .setMessage(R.string.cerrar_sesion_mensaje)
                .setPositiveButton(R.string.cerrar_sesion, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialogo, int boton) {
                        salir();
                    }
                })
                .setNegativeButton(R.string.cancelar, null)
                .show();
    }

    private void salir() {
        new Sesion(this).cerrar();
        startActivity(new Intent(this, LoginActivity.class));
        finish();
    }

    // El trabajador ve su DUI y sus oficios, y elige varias colonias; el cliente, la colonia donde vive
    private void mostrarSegunRol() {
        TextView txtRol = findViewById(R.id.txtRol);
        TextView txtZona = findViewById(R.id.txtZona);
        txtRol.setText(esTrabajador ? R.string.rol_trabajador : R.string.rol_cliente);
        txtZona.setText(esTrabajador ? R.string.etiqueta_zona_trabajo : R.string.etiqueta_zona_cliente);
        findViewById(R.id.vistaDui).setVisibility(esTrabajador ? View.VISIBLE : View.GONE);
        findViewById(R.id.vistaTrabajo).setVisibility(esTrabajador ? View.VISIBLE : View.GONE);
        zona.elegirVarias(esTrabajador);
    }

    private void cargar() {
        ClienteApi.pedir(this, "GET", "api/perfil", null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                mostrar(cuerpo);
            }

            @Override
            public void alError(int codigo, String mensaje) {
                txtCargando.setText(R.string.error_cargar);
            }
        });
    }

    private void mostrar(String cuerpo) {
        Perfil perfil;
        try {
            perfil = new Perfil(new JSONObject(cuerpo));
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        edtNombre.setText(perfil.nombre);
        edtTelefono.setText(perfil.telefono);
        recordarGuardado();
        txtDui.setText(perfil.duiEnmascarado);
        txtCalificacion.setText(getString(R.string.calificacion_perfil,
                Formato.calificacion(this, perfil.promedioCalificacion, perfil.totalCalificaciones)));
        if (perfil.fotoUrl != null) {
            mostrarFoto(perfil.fotoUrl);
        }
        zona.cargar(perfil.departamentoId, perfil.municipioId, perfil.colonias);
        if (esTrabajador) {
            CasillasOficios.cargar(this, vistaOficios, perfil.oficios);
        }

        txtCargando.setVisibility(View.GONE);
        vistaPerfil.setVisibility(View.VISIBLE);
    }

    private void mostrarFoto(String ruta) {
        ClienteApi.pedirImagen(this, ruta, new ClienteApi.RespuestaImagen() {
            @Override
            public void alRecibir(Bitmap imagen) {
                imgFoto.setImageBitmap(imagen);
            }
        });
    }

    // Botón Cambiar foto: abre el selector de imágenes del teléfono, que no necesita permiso de almacenamiento
    public void cambiarFoto(View vista) {
        Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
        intent.setType("image/*");
        try {
            startActivityForResult(intent, ELEGIR_FOTO);
        } catch (ActivityNotFoundException e) {
            Toast.makeText(this, R.string.sin_selector_fotos, Toast.LENGTH_LONG).show();
        }
    }

    @Override
    protected void onActivityResult(int codigo, int resultado, Intent datos) {
        super.onActivityResult(codigo, resultado, datos);
        if (codigo == ELEGIR_FOTO && resultado == RESULT_OK && datos != null && datos.getData() != null) {
            subirFoto(datos.getData());
        }
    }

    // La API responde con la ruta de la foto nueva, que se descarga para mostrarla
    private void subirFoto(Uri foto) {
        btnCambiarFoto.setEnabled(false);
        btnCambiarFoto.setText(R.string.subiendo_foto);
        ClienteApi.subirFoto(this, foto, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                liberarBotonFoto();
                Toast.makeText(PerfilActivity.this, R.string.foto_actualizada, Toast.LENGTH_SHORT).show();
                try {
                    mostrarFoto(new JSONObject(cuerpo).getString("fotoUrl"));
                } catch (JSONException e) {
                    // la foto nueva se verá al volver a abrir el perfil
                }
            }

            @Override
            public void alError(int codigo, String mensaje) {
                liberarBotonFoto();
            }
        });
    }

    private void liberarBotonFoto() {
        btnCambiarFoto.setEnabled(true);
        btnCambiarFoto.setText(R.string.cambiar_foto);
    }

    // Botón Guardar cambios: primero datos y zona; el trabajador sigue con sus oficios y después sus colonias
    public void guardar(View vista) {
        if (guardando) {
            return;
        }
        final String nombre = edtNombre.getText().toString().trim();
        String telefono = edtTelefono.getText().toString().trim();
        int falta = validar(nombre, telefono);
        if (falta != 0) {
            Toast.makeText(this, falta, Toast.LENGTH_SHORT).show();
            return;
        }

        JSONObject cuerpo = new JSONObject();
        try {
            cuerpo.put("nombre", nombre);
            cuerpo.put("telefono", telefono);
            cuerpo.put("municipioId", zona.municipioId());
            if (!esTrabajador) {
                cuerpo.put("coloniaId", zona.coloniaId());
            }
        } catch (JSONException e) {
            return;
        }

        guardando = true;
        Ventana.ocupar(btnGuardar, R.string.guardando);
        guardarParte("api/perfil", cuerpo.toString(), new Runnable() {
            @Override
            public void run() {
                if (esTrabajador) {
                    guardarOficios(nombre);
                } else {
                    terminarGuardado(nombre);
                }
            }
        });
    }

    private void guardarOficios(final String nombre) {
        String cuerpo = listaJson("oficios", CasillasOficios.marcados(vistaOficios));
        guardarParte("api/perfil/oficios", cuerpo, new Runnable() {
            @Override
            public void run() {
                guardarColonias(nombre);
            }
        });
    }

    private void guardarColonias(final String nombre) {
        String cuerpo = listaJson("colonias", zona.coloniaIds());
        guardarParte("api/perfil/colonias", cuerpo, new Runnable() {
            @Override
            public void run() {
                terminarGuardado(nombre);
            }
        });
    }

    // Un PUT del guardado: si sale bien sigue con el paso siguiente; si falla, ClienteApi ya mostró el mensaje
    private void guardarParte(String ruta, String cuerpo, final Runnable siguiente) {
        ClienteApi.pedir(this, "PUT", ruta, cuerpo, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String respuesta) {
                siguiente.run();
            }

            @Override
            public void alError(int codigo, String mensaje) {
                guardando = false;
                Ventana.liberar(btnGuardar, R.string.boton_guardar);
            }
        });
    }

    private void terminarGuardado(String nombre) {
        guardando = false;
        Ventana.liberar(btnGuardar, R.string.boton_guardar);
        recordarGuardado();
        new Sesion(this).guardarNombre(nombre);
        Toast.makeText(this, R.string.perfil_guardado, Toast.LENGTH_SHORT).show();
    }

    // Por ejemplo { "oficios": [1, 3] }
    private String listaJson(String campo, ArrayList<Integer> ids) {
        JSONObject json = new JSONObject();
        try {
            json.put(campo, new JSONArray(ids));
        } catch (JSONException e) {
            // solo falla con un nombre de campo null
        }
        return json.toString();
    }

    // Devuelve el texto a mostrar si falta algo, o 0 si está completo. El servidor vuelve a validar todo.
    private int validar(String nombre, String telefono) {
        if (nombre.isEmpty()) {
            return R.string.falta_nombre;
        }
        int errorTelefono = Validacion.TELEFONO.error(telefono);
        if (errorTelefono != 0) {
            return errorTelefono;
        }
        if (zona.municipioId() == 0) {
            return R.string.falta_municipio;
        }
        if (!esTrabajador) {
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
