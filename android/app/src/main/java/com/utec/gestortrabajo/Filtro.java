package com.utec.gestortrabajo;

import android.app.Activity;
import android.view.LayoutInflater;
import android.view.View;

import com.google.android.material.chip.Chip;
import com.google.android.material.chip.ChipGroup;

import java.util.List;

// Filtro de una lista como una fila de chips con una sola opción activa. Lo usan las tres listas.
public class Filtro {

    public interface AlCambiar {
        void cambio();
    }

    // Pone un chip por cada texto y deja marcado el primero. Solo los cambios posteriores avisan,
    // así que la primera carga de la lista la pide la pantalla.
    public static void llenar(Activity pantalla, ChipGroup grupo, String[] textos, final AlCambiar alCambiar) {
        grupo.setOnCheckedStateChangeListener(null);
        grupo.removeAllViews();
        LayoutInflater inflador = LayoutInflater.from(pantalla);
        for (String texto : textos) {
            Chip chip = (Chip) inflador.inflate(R.layout.chip_filtro, grupo, false);
            chip.setId(View.generateViewId());
            chip.setText(texto);
            grupo.addView(chip);
        }
        grupo.check(grupo.getChildAt(0).getId());
        grupo.setOnCheckedStateChangeListener(new ChipGroup.OnCheckedStateChangeListener() {
            @Override
            public void onCheckedChanged(ChipGroup chips, List<Integer> idsMarcados) {
                alCambiar.cambio();
            }
        });
    }

    // Posición de la opción marcada, empezando en 0
    public static int posicion(ChipGroup grupo) {
        int posicion = grupo.indexOfChild(grupo.findViewById(grupo.getCheckedChipId()));
        return Math.max(posicion, 0);
    }
}
