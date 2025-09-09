import numpy as np
import torch
import torch.nn.functional as F
import os

def save_to_file(filename, data, original_shape):
  #Save to file, line first, then row, then frame
    with open(filename, 'w') as f:
        reshaped_data = data.reshape(-1, 1)
        np.savetxt(f, reshaped_data.cpu().numpy(), fmt='%d')
        f.write(f"// Original shape: {original_shape}\n")
        f.write(f"/* Original data:\n")
        f.write(str(data))
        f.write(f"*/\n")

def test():

    filtersize = 5
    ifmapchannelnum = 1
    ofmapchannelnum = 1
    ifmapsize = 25

    # Threshold
    threshold=32

    # Generate filter_L1
    filter_L1 = torch.randint(6, (ofmapchannelnum,ifmapchannelnum,filtersize,filtersize)).float()

    # print("filter_L1:")
    # print(filter_L1)

    # Generate 1x25x25 ifmap_t1 and ifmap_t2
    ifmap_t1 = torch.randint(2, (ifmapchannelnum, ifmapsize, ifmapsize)).reshape(1,ifmapchannelnum,ifmapsize,ifmapsize).float()
    ifmap_t2 = torch.randint(2, (ifmapchannelnum, ifmapsize, ifmapsize)).reshape(1,ifmapchannelnum,ifmapsize,ifmapsize).float()

    # print("ifmap_t1:")
    # print(ifmap_t1)
    # print("ifmap_t2:")
    # print(ifmap_t2)

    # Perform convolutions, spike and residue calculation for timestep 1
    L1_conv_out_t1 = F.conv2d(ifmap_t1, filter_L1)

    L1_out_spike_t1 = (L1_conv_out_t1 > threshold).int()
    L1_residue_t1 = L1_conv_out_t1 - L1_out_spike_t1 * threshold

    print("Timestep 1:")
    # print("L1_conv_out_t1:")
    # print("L1_conv_out_t1 shape:", L1_conv_out_t1.shape)
    # print(L1_conv_out_t1)
    print("L1_out_spike_t1:")
    print("L1_out_spike_t1 shape:", L1_out_spike_t1.shape)
    print(L1_out_spike_t1)
    # print("L1_residue_t1:")
    # print("L1_residue_t1 shape:", L1_residue_t1.shape)
    # print(L1_residue_t1)


    # Perform convolutions, spike and residue calculation for timestep 2
    L1_conv_out_t2 = F.conv2d(ifmap_t2, filter_L1)

    L1_out_spike_t2 = (L1_conv_out_t2 > threshold).int()
    L1_residue_t2 = L1_conv_out_t2 - L1_out_spike_t2 * threshold


    print("Timestep 2:")
    # print("L1_conv_out_t2:")
    # print("L1_conv_out_t2 shape:", L1_conv_out_t2.shape)
    # print(L1_conv_out_t2)
    print("L1_out_spike_t2:")
    print("L1_out_spike_t2 shape:", L1_out_spike_t2.shape)
    print(L1_out_spike_t2)
    # print("L1_residue_t2:")
    # print("L1_residue2 shape:", L1_residue_t2.shape)
    # print(L1_residue_t2)

    #Save to file
    os.makedirs("scnn_data", exist_ok=True)

    #FILTER
    save_to_file("scnn_data/L1_filter.txt", filter_L1, filter_L1.shape)
    #IFMAP
    save_to_file("scnn_data/ifmap_t1.txt", ifmap_t1, ifmap_t1.shape)
    save_to_file("scnn_data/ifmap_t2.txt", ifmap_t2, ifmap_t2.shape)
    # Spikes
    save_to_file("scnn_data/L1_out_spike_t1.txt", L1_out_spike_t1, L1_out_spike_t1.shape)
    save_to_file("scnn_data/L1_out_spike_t2.txt", L1_out_spike_t2, L1_out_spike_t2.shape)
    #RESIDUE
    save_to_file("scnn_data/L1_residue_t1.txt", L1_residue_t1, L1_residue_t1.shape)
    save_to_file("scnn_data/L1_residue_t2.txt", L1_residue_t2, L1_residue_t2.shape)


if __name__ == '__main__':
    test()
