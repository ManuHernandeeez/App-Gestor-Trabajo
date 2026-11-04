package com.utec.gestortrabajo;

import android.content.Context;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.ArrayList;

// Burbujas de una conversación: los mensajes propios a la derecha y en color de marca, los demás a la izquierda.
public class AdaptadorMensajes extends BaseAdapter {

    private final Context contexto;
    private final ArrayList<Mensaje> mensajes;
    private final LayoutInflater inflador;

    public AdaptadorMensajes(Context contexto, ArrayList<Mensaje> mensajes) {
        this.contexto = contexto;
        this.mensajes = mensajes;
        this.inflador = LayoutInflater.from(contexto);
    }

    @Override
    public int getCount() {
        return mensajes.size();
    }

    @Override
    public Object getItem(int posicion) {
        return mensajes.get(posicion);
    }

    @Override
    public long getItemId(int posicion) {
        return mensajes.get(posicion).id;
    }

    @Override
    public View getView(int posicion, View vista, ViewGroup padre) {
        if (vista == null) {
            vista = inflador.inflate(R.layout.item_mensaje, padre, false);
        }
        Mensaje mensaje = mensajes.get(posicion);

        TextView txtTexto = vista.findViewById(R.id.txtTexto);
        TextView txtHora = vista.findViewById(R.id.txtHora);
        txtTexto.setText(mensaje.texto);
        txtHora.setText(Formato.fechaHora(mensaje.fecha));

        int lado = mensaje.esMio ? Gravity.END : Gravity.START;
        alinear(txtTexto, lado);
        alinear(txtHora, lado);
        txtTexto.setBackgroundResource(mensaje.esMio ? R.drawable.fondo_burbuja_mia : R.drawable.fondo_burbuja);
        txtTexto.setTextColor(contexto.getColor(mensaje.esMio ? R.color.white : R.color.texto));
        return vista;
    }

    private void alinear(TextView texto, int lado) {
        LinearLayout.LayoutParams parametros = (LinearLayout.LayoutParams) texto.getLayoutParams();
        parametros.gravity = lado;
        texto.setLayoutParams(parametros);
    }
}
