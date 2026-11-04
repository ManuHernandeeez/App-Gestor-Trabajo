package com.utec.gestortrabajo;

import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.AdapterView;
import android.widget.EditText;
import android.widget.GridLayout;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.button.MaterialButtonToggleGroup;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Locale;

// Pantalla del administrador: resumen de reportes y búsqueda de usuarios para suspenderlos o reactivarlos.
// Tocar un usuario muestra sus datos de auditoría (correo, teléfono y DUI), que salen solo de la API de administración.
public class AdminUsuariosActivity extends AppCompatActivity {

    // Espera que la persona deje de escribir antes de buscar
    private static final int ESPERA_BUSQUEDA = 400;

    private MaterialButtonToggleGroup vistaPestana;
    private View vistaReportes;
    private View vistaUsuarios;
    private TextView txtReportesEstado;
    private GridLayout cuadriculaReportes;
    private TextView txtVacio;
    private EditText edtBuscar;
    private final ArrayList<UsuarioAdmin> usuarios = new ArrayList<UsuarioAdmin>();
    private AdaptadorUsuariosAdmin adaptador;
    private final Handler espera = new Handler(Looper.getMainLooper());
    private Runnable busquedaPendiente;
    private int numeroDeBusqueda = 0;
    private boolean ocupado = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_admin_usuarios);
        Ventana.preparar(this, findViewById(R.id.raiz));
        Barra.preparar(this, R.id.btnBarraUsuarios);
        Atras.protegerSiempre(this, Atras.salirDeLaApp());

        vistaReportes = findViewById(R.id.vistaReportes);
        vistaUsuarios = findViewById(R.id.vistaUsuarios);
        txtReportesEstado = findViewById(R.id.txtReportesEstado);
        cuadriculaReportes = findViewById(R.id.cuadriculaReportes);
        txtVacio = findViewById(R.id.txtVacio);
        edtBuscar = findViewById(R.id.edtBuscar);

        adaptador = new AdaptadorUsuariosAdmin(this, usuarios, new AdaptadorUsuariosAdmin.AlElegir() {
            @Override
            public void cambiarEstado(UsuarioAdmin usuario) {
                confirmarCambioDeEstado(usuario);
            }
        });
        ListView listaUsuarios = findViewById(R.id.listaUsuarios);
        listaUsuarios.setAdapter(adaptador);
        listaUsuarios.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> padre, View vista, int posicion, long id) {
                verAuditoria(usuarios.get(posicion));
            }
        });

        edtBuscar.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence texto, int inicio, int cuenta, int despues) {
            }

            @Override
            public void onTextChanged(CharSequence texto, int inicio, int antes, int cuenta) {
            }

            @Override
            public void afterTextChanged(Editable texto) {
                programarBusqueda();
            }
        });

        vistaPestana = findViewById(R.id.vistaPestana);
        vistaPestana.addOnButtonCheckedListener(new MaterialButtonToggleGroup.OnButtonCheckedListener() {
            @Override
            public void onButtonChecked(MaterialButtonToggleGroup grupo, int idBoton, boolean marcado) {
                if (marcado) {
                    mostrarPestana(idBoton == R.id.btnPestanaReportes);
                }
            }
        });
        cargarUsuarios();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (busquedaPendiente != null) {
            espera.removeCallbacks(busquedaPendiente);
        }
    }

    // Botón Cerrar sesión: pide confirmar
    public void cerrarSesion(View vista) {
        new MaterialAlertDialogBuilder(this)
                .setTitle(R.string.cerrar_sesion)
                .setMessage(R.string.cerrar_sesion_mensaje)
                .setPositiveButton(R.string.cerrar_sesion, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialogo, int boton) {
                        new Sesion(AdminUsuariosActivity.this).cerrar();
                        startActivity(new Intent(AdminUsuariosActivity.this, LoginActivity.class));
                        finish();
                    }
                })
                .setNegativeButton(R.string.cancelar, null)
                .show();
    }

    private void mostrarPestana(boolean reportes) {
        vistaReportes.setVisibility(reportes ? View.VISIBLE : View.GONE);
        vistaUsuarios.setVisibility(reportes ? View.GONE : View.VISIBLE);
        if (reportes) {
            cargarReportes();
        }
    }

    // Reportes

    private void cargarReportes() {
        txtReportesEstado.setText(R.string.cargando);
        txtReportesEstado.setVisibility(View.VISIBLE);
        ClienteApi.pedir(this, "GET", "api/admin/reportes/resumen", null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                mostrarReportes(cuerpo);
            }

            @Override
            public void alError(int codigo, String mensaje) {
                txtReportesEstado.setText(R.string.error_cargar);
            }
        });
    }

    private void mostrarReportes(String cuerpo) {
        try {
            JSONObject json = new JSONObject(cuerpo);
            cuadriculaReportes.removeAllViews();
            agregarCifra(String.valueOf(json.getInt("totalSolicitudes")), R.string.reporte_solicitudes);
            agregarCifra(String.valueOf(json.getInt("publicadas")), R.string.estado_publicada);
            agregarCifra(String.valueOf(json.getInt("asignadas")), R.string.estado_asignada);
            agregarCifra(String.valueOf(json.getInt("enProceso")), R.string.estado_en_proceso);
            agregarCifra(String.valueOf(json.getInt("finalizadas")), R.string.estado_finalizada);
            agregarCifra(String.valueOf(json.getInt("canceladas")), R.string.estado_cancelada);
            agregarCifra(String.valueOf(json.getInt("vencidas")), R.string.estado_vencida);
            agregarCifra(promedio(json), R.string.reporte_promedio);
            agregarCifra(String.valueOf(json.getInt("totalCalificaciones")), R.string.reporte_calificaciones);
            agregarCifra(String.valueOf(json.getInt("clientes")), R.string.reporte_clientes);
            agregarCifra(String.valueOf(json.getInt("trabajadores")), R.string.reporte_trabajadores);
            agregarCifra(String.valueOf(json.getInt("suspendidos")), R.string.reporte_suspendidos);
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        txtReportesEstado.setVisibility(View.GONE);
    }

    private String promedio(JSONObject json) throws JSONException {
        if (json.getInt("totalCalificaciones") == 0) {
            return getString(R.string.sin_valor);
        }
        return String.format(Locale.US, "%.1f", json.getDouble("promedioGeneral"));
    }

    private void agregarCifra(String valor, int etiqueta) {
        View cifra = LayoutInflater.from(this).inflate(R.layout.item_estadistica, cuadriculaReportes, false);
        ((TextView) cifra.findViewById(R.id.txtValor)).setText(valor);
        ((TextView) cifra.findViewById(R.id.txtEtiqueta)).setText(etiqueta);
        cuadriculaReportes.addView(cifra);
    }

    // Usuarios

    private void programarBusqueda() {
        if (busquedaPendiente != null) {
            espera.removeCallbacks(busquedaPendiente);
        }
        busquedaPendiente = new Runnable() {
            @Override
            public void run() {
                cargarUsuarios();
            }
        };
        espera.postDelayed(busquedaPendiente, ESPERA_BUSQUEDA);
    }

    private void cargarUsuarios() {
        String texto = edtBuscar.getText().toString().trim();
        String ruta = "api/admin/usuarios";
        if (!texto.isEmpty()) {
            ruta = ruta + "?q=" + codificar(texto);
        }

        txtVacio.setText(R.string.cargando);
        txtVacio.setVisibility(View.VISIBLE);
        // si se escribe otra cosa antes de que llegue la respuesta, la vieja se ignora
        final int mia = ++numeroDeBusqueda;
        ClienteApi.pedir(this, "GET", ruta, null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                if (mia == numeroDeBusqueda) {
                    mostrarUsuarios(cuerpo);
                }
            }

            @Override
            public void alError(int codigo, String mensaje) {
                if (mia == numeroDeBusqueda) {
                    txtVacio.setText(R.string.error_cargar);
                }
            }
        });
    }

    private void mostrarUsuarios(String cuerpo) {
        try {
            JSONArray arreglo = new JSONArray(cuerpo);
            usuarios.clear();
            for (int i = 0; i < arreglo.length(); i++) {
                usuarios.add(new UsuarioAdmin(arreglo.getJSONObject(i)));
            }
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        adaptador.notifyDataSetChanged();
        txtVacio.setText(R.string.vacio_usuarios);
        txtVacio.setVisibility(usuarios.isEmpty() ? View.VISIBLE : View.GONE);
    }

    private void confirmarCambioDeEstado(final UsuarioAdmin usuario) {
        final boolean suspender = !usuario.estaSuspendido();
        new MaterialAlertDialogBuilder(this)
                .setTitle(suspender ? R.string.suspender_titulo : R.string.reactivar_titulo)
                .setMessage(getString(suspender ? R.string.suspender_mensaje : R.string.reactivar_mensaje, usuario.nombre))
                .setPositiveButton(suspender ? R.string.boton_suspender : R.string.boton_reactivar,
                        new DialogInterface.OnClickListener() {
                            @Override
                            public void onClick(DialogInterface dialogo, int boton) {
                                cambiarEstado(usuario, suspender);
                            }
                        })
                .setNegativeButton(R.string.cancelar, null)
                .show();
    }

    // Después se recarga la búsqueda, salga bien o no
    private void cambiarEstado(UsuarioAdmin usuario, final boolean suspender) {
        if (ocupado) {
            return;
        }
        ocupado = true;
        String accion = suspender ? "suspender" : "reactivar";
        ClienteApi.pedir(this, "PUT", "api/admin/usuarios/" + usuario.id + "/" + accion, null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                ocupado = false;
                Toast.makeText(AdminUsuariosActivity.this,
                        suspender ? R.string.usuario_suspendido_ok : R.string.usuario_reactivado_ok, Toast.LENGTH_SHORT).show();
                cargarUsuarios();
            }

            @Override
            public void alError(int codigo, String mensaje) {
                ocupado = false;
                cargarUsuarios();
            }
        });
    }

    private void verAuditoria(UsuarioAdmin usuario) {
        ClienteApi.pedir(this, "GET", "api/admin/usuarios/" + usuario.id + "/auditoria", null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                mostrarAuditoria(cuerpo);
            }

            @Override
            public void alError(int codigo, String mensaje) {
                // el mensaje de la API ya se mostró
            }
        });
    }

    private void mostrarAuditoria(String cuerpo) {
        String texto;
        String nombre;
        try {
            JSONObject json = new JSONObject(cuerpo);
            nombre = json.getString("nombre");
            StringBuilder datos = new StringBuilder();
            datos.append(getString(R.string.auditoria_correo, json.getString("correo")));
            datos.append("\n").append(getString(R.string.auditoria_telefono, valor(json, "telefono")));
            if (!json.isNull("dui")) {
                datos.append("\n").append(getString(R.string.auditoria_dui, json.getString("dui")));
            }
            datos.append("\n").append(getString(R.string.auditoria_zona, valor(json, "zona")));
            datos.append("\n").append(getString(R.string.auditoria_registro, Formato.fecha(json.getString("fechaRegistro"))));
            texto = datos.toString();
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        new MaterialAlertDialogBuilder(this)
                .setTitle(nombre)
                .setMessage(texto)
                .setPositiveButton(R.string.sync_entendido, null)
                .show();
    }

    private String valor(JSONObject json, String campo) throws JSONException {
        return json.isNull(campo) ? getString(R.string.sin_dato) : json.getString(campo);
    }

    // Un texto con espacios, tildes o símbolos debe escribirse codificado en una dirección web
    private String codificar(String texto) {
        try {
            return URLEncoder.encode(texto, "UTF-8");
        } catch (java.io.UnsupportedEncodingException e) {
            return texto;
        }
    }
}
