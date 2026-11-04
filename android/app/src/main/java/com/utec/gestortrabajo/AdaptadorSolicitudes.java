package com.utec.gestortrabajo;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.TextView;

import java.util.ArrayList;

public class AdaptadorSolicitudes extends BaseAdapter {

    private final Context contexto;
    private final ArrayList<SolicitudResumen> solicitudes;
    private final LayoutInflater inflador;

    public AdaptadorSolicitudes(Context contexto, ArrayList<SolicitudResumen> solicitudes) {
        this.contexto = contexto;
        this.solicitudes = solicitudes;
        this.inflador = LayoutInflater.from(contexto);
    }

    @Override
    public int getCount() {
        return solicitudes.size();
    }

    @Override
    public Object getItem(int posicion) {
        return solicitudes.get(posicion);
    }

    @Override
    public long getItemId(int posicion) {
        return solicitudes.get(posicion).id;
    }

    @Override
    public View getView(int posicion, View vista, ViewGroup padre) {
        if (vista == null) {
            vista = inflador.inflate(R.layout.item_solicitud, padre, false);
        }
        SolicitudResumen solicitud = solicitudes.get(posicion);

        ((TextView) vista.findViewById(R.id.txtTitulo)).setText(solicitud.titulo);
        ((TextView) vista.findViewById(R.id.txtOficio)).setText(solicitud.oficio);
        ((TextView) vista.findViewById(R.id.txtZona)).setText(solicitud.zona);
        ((TextView) vista.findViewById(R.id.txtPresupuesto)).setText(Formato.dinero(solicitud.presupuesto));
        ((TextView) vista.findViewById(R.id.txtPropuestas)).setText(Formato.propuestas(contexto, solicitud.propuestas));

        EstadoSolicitud.pintar((TextView) vista.findViewById(R.id.txtEstado), solicitud.estado);
        return vista;
    }
}
