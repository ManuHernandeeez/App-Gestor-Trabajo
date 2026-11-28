package com.utec.gestortrabajo;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.Button;
import android.widget.RatingBar;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.Locale;

// Propuestas de una solicitud para el cliente. Los botones Aceptar y Rechazar solo salen en las pendientes
// y mientras la solicitud siga publicada. El botón de chat sale mientras el chat con ese trabajador admite mensajes.
public class AdaptadorPropuestas extends BaseAdapter {

    public interface AlElegir {
        void aceptar(Propuesta propuesta);

        void rechazar(Propuesta propuesta);

        void chatear(Propuesta propuesta);
    }

    private final Context contexto;
    private final ArrayList<Propuesta> propuestas;
    private final AlElegir alElegir;
    private final LayoutInflater inflador;
    private String estadoSolicitud = "";

    public AdaptadorPropuestas(Context contexto, ArrayList<Propuesta> propuestas, AlElegir alElegir) {
        this.contexto = contexto;
        this.propuestas = propuestas;
        this.alElegir = alElegir;
        this.inflador = LayoutInflater.from(contexto);
    }

    public void establecerEstadoSolicitud(String estado) {
        estadoSolicitud = estado;
        notifyDataSetChanged();
    }

    @Override
    public int getCount() {
        return propuestas.size();
    }

    @Override
    public Object getItem(int posicion) {
        return propuestas.get(posicion);
    }

    @Override
    public long getItemId(int posicion) {
        return propuestas.get(posicion).id;
    }

    @Override
    public View getView(int posicion, View vista, ViewGroup padre) {
        if (vista == null) {
            vista = inflador.inflate(R.layout.item_propuesta, padre, false);
        }
        final Propuesta propuesta = propuestas.get(posicion);

        ((TextView) vista.findViewById(R.id.txtInicial)).setText(inicial(propuesta.trabajadorNombre));
        ((TextView) vista.findViewById(R.id.txtTrabajador)).setText(propuesta.trabajadorNombre);
        ((RatingBar) vista.findViewById(R.id.vistaEstrellas)).setRating((float) propuesta.promedioCalificacion);
        ((TextView) vista.findViewById(R.id.txtCalificacion)).setText(
                Formato.calificacion(contexto, propuesta.promedioCalificacion, propuesta.totalCalificaciones));
        ((TextView) vista.findViewById(R.id.txtPrecio)).setText(Formato.dinero(propuesta.precio));
        EstadoPropuesta.pintar((TextView) vista.findViewById(R.id.txtEstado), propuesta.estado);

        TextView txtMensaje = vista.findViewById(R.id.txtMensaje);
        txtMensaje.setText(propuesta.mensaje);
        txtMensaje.setVisibility(propuesta.mensaje.isEmpty() ? View.GONE : View.VISIBLE);

        Button btnChatear = vista.findViewById(R.id.btnChatear);
        btnChatear.setVisibility(Chat.abierto(propuesta.estado, estadoSolicitud) ? View.VISIBLE : View.GONE);
        btnChatear.setText(contexto.getString(R.string.boton_chatear_trabajador, propuesta.trabajadorNombre));
        btnChatear.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View boton) {
                alElegir.chatear(propuesta);
            }
        });

        boolean conBotones = estadoSolicitud.equals("publicada") && propuesta.estado.equals("pendiente");
        vista.findViewById(R.id.vistaBotones).setVisibility(conBotones ? View.VISIBLE : View.GONE);
        vista.findViewById(R.id.btnAceptar).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View boton) {
                alElegir.aceptar(propuesta);
            }
        });
        vista.findViewById(R.id.btnRechazar).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View boton) {
                alElegir.rechazar(propuesta);
            }
        });
        return vista;
    }

    // Primera letra del nombre, para el círculo que hace de foto mientras la API no entregue la del trabajador
    private String inicial(String nombre) {
        String limpio = nombre.trim();
        return limpio.isEmpty() ? "" : limpio.substring(0, 1).toUpperCase(Locale.getDefault());
    }
}
