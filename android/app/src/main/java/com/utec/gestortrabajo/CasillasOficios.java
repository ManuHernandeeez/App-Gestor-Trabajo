package com.utec.gestortrabajo;

import android.app.Activity;
import android.view.LayoutInflater;
import android.widget.Toast;

import com.google.android.material.chip.Chip;
import com.google.android.material.chip.ChipGroup;

import org.json.JSONException;

import java.util.ArrayList;

// Oficios del trabajador como chips que se marcan, uno por cada oficio activo del catálogo. Lo usan el registro y el perfil.
public class CasillasOficios {

    // Pide el catálogo y pone los chips dentro de la vista; quedan marcados los de los ids dados
    public static void cargar(final Activity pantalla, final ChipGroup vista, final ArrayList<Integer> marcados) {
        ClienteApi.pedir(pantalla, "GET", "api/catalogos/oficios", null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                try {
                    llenar(pantalla, vista, ElementoCatalogo.desdeJson(cuerpo), marcados);
                } catch (JSONException e) {
                    Toast.makeText(pantalla, R.string.error_inesperado, Toast.LENGTH_LONG).show();
                }
            }

            @Override
            public void alError(int codigo, String mensaje) {
            }
        });
    }

    // Ids de los oficios marcados
    public static ArrayList<Integer> marcados(ChipGroup vista) {
        ArrayList<Integer> ids = new ArrayList<Integer>();
        for (int i = 0; i < vista.getChildCount(); i++) {
            Chip chip = (Chip) vista.getChildAt(i);
            if (chip.isChecked()) {
                ids.add((Integer) chip.getTag());
            }
        }
        return ids;
    }

    // Cada chip guarda en su tag el id del oficio
    private static void llenar(Activity pantalla, ChipGroup vista, ArrayList<ElementoCatalogo> oficios,
                               ArrayList<Integer> marcados) {
        vista.removeAllViews();
        LayoutInflater inflador = LayoutInflater.from(pantalla);
        for (ElementoCatalogo oficio : oficios) {
            Chip chip = (Chip) inflador.inflate(R.layout.chip_oficio, vista, false);
            chip.setText(oficio.nombre);
            chip.setTag(oficio.id);
            chip.setChecked(marcados.contains(oficio.id));
            vista.addView(chip);
        }
    }
}
