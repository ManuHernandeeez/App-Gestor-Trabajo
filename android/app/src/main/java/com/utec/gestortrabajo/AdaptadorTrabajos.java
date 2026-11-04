package com.utec.gestortrabajo;

import android.content.Context;
import android.graphics.drawable.GradientDrawable;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.TextView;

import java.util.ArrayList;

public class AdaptadorTrabajos extends BaseAdapter {

    private final Context contexto;
    private final ArrayList<TrabajoZona> trabajos;
    private final LayoutInflater inflador;

    public AdaptadorTrabajos(Context contexto, ArrayList<TrabajoZona> trabajos) {
        this.contexto = contexto;
        this.trabajos = trabajos;
        this.inflador = LayoutInflater.from(contexto);
    }

    @Override
    public int getCount() {
        return trabajos.size();
    }

    @Override
    public Object getItem(int posicion) {
        return trabajos.get(posicion);
    }

    @Override
    public long getItemId(int posicion) {
        return trabajos.get(posicion).id;
    }

    @Override
    public View getView(int posicion, View vista, ViewGroup padre) {
        if (vista == null) {
            vista = inflador.inflate(R.layout.item_trabajo, padre, false);
        }
        TrabajoZona trabajo = trabajos.get(posicion);

        ((TextView) vista.findViewById(R.id.txtTitulo)).setText(trabajo.titulo);
        ((TextView) vista.findViewById(R.id.txtOficio)).setText(trabajo.oficio);
        ((TextView) vista.findViewById(R.id.txtZona)).setText(trabajo.zona);
        ((TextView) vista.findViewById(R.id.txtCliente)).setText(trabajo.clienteNombre);
        ((TextView) vista.findViewById(R.id.txtPresupuesto)).setText(Formato.dinero(trabajo.presupuesto));
        ((TextView) vista.findViewById(R.id.txtTiempo)).setText(Formato.hace(contexto, trabajo.publicadaHaceHoras));

        // "Ya propuse" es informativo: azul, como un trabajo en curso
        TextView txtYaPropuse = vista.findViewById(R.id.txtYaPropuse);
        txtYaPropuse.setVisibility(trabajo.yaPropuse ? View.VISIBLE : View.GONE);
        txtYaPropuse.setTextColor(contexto.getColor(R.color.info_texto));
        GradientDrawable fondo = (GradientDrawable) txtYaPropuse.getBackground().mutate();
        fondo.setColor(contexto.getColor(R.color.info_fondo));
        return vista;
    }
}
