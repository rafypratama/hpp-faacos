<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class SyncRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     */
    public function rules(): array
    {
        return [
            'items' => 'required|array|min:1',
            'items.*.action_type' => 'required|string|in:create_formula,approve_formula,schedule_production,verify_material_request,adjust_stock,add_ingredient',
            'items.*.payload' => 'required|array',
            'items.*.timestamp' => 'required|integer',
        ];
    }

    /**
     * Custom error messages.
     */
    public function messages(): array
    {
        return [
            'items.required' => 'Tidak ada item yang akan disinkronkan.',
            'items.*.action_type.in' => 'Tipe aksi tidak dikenali oleh server.',
        ];
    }
}
