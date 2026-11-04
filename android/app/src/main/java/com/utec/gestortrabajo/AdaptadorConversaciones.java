package com.utec.gestortrabajo;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.Locale;

public class AdaptadorConversaciones extends BaseAdapter {

    private final Context contexto;
    private final ArrayList<Conversacion> conversaciones;
    private final LayoutInflater inflador;

    public AdaptadorConversaciones(Context contexto, ArrayList<Conversacion> conversaciones) {
        this.contexto = contexto;
        this.conversaciones = conversaciones;
        this.inflador = LayoutInflater.from(contexto);
    }

    @Override
    public int getCount() {
        return conversaciones.size();
    }

    @Override
    public Object getItem(int posicion) {
        return conversaciones.get(posicion);
    }

    @Override
    public long getItemId(int posicion) {
        return conversaciones.get(posicion).solicitudId;
    }

    @Override
    public View getView(int posicion, View vista, ViewGroup padre) {
        if (vista == null) {
            vista = inflador.inflate(R.layout.item_conversacion, padre, false);
        }
        Conversacion conversacion = conversaciones.get(posicion);

        String nombre = conversacion.otraParteNombre;
        ((TextView) vista.findViewById(R.id.txtInicial)).setText(nombre.substring(0, 1).toUpperCase(Locale.getDefault()));
        ((TextView) vista.findViewById(R.id.txtNombre)).setText(nombre);
        ((TextView) vista.findViewById(R.id.txtTrabajo)).setText(conversacion.titulo);
        ((TextView) vista.findViewById(R.id.txtUltimo)).setText(conversacion.ultimoMensaje == null
                ? contexto.getString(R.string.sin_mensajes_aun) : conversacion.ultimoMensaje);
        ((TextView) vista.findViewById(R.id.txtFecha)).setText(conversacion.fechaUltimo == null
                ? "" : Formato.fechaHora(conversacion.fechaUltimo));

        TextView txtNuevos = vista.findViewById(R.id.txtNuevos);
        txtNuevos.setVisibility(conversacion.mensajesNuevos > 0 ? View.VISIBLE : View.GONE);
        txtNuevos.setText(String.valueOf(conversacion.mensajesNuevos));
        return vista;
    }
}
